require('dotenv').config();

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const crypto = require('crypto');
const db = require('./db');
const { uploadImage, deleteImage } = require('./oss');
const { sniffImageType, moderateImage } = require('./moderation');

const app = express();
const PORT = process.env.PORT || 8080;

app.set('trust proxy', 1);  // nginx 反代后取真实 IP（限流用）
app.use(cors());
app.use(express.json({ limit: '15mb' }));
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// ============ 工具函数 ============

function uuid() {
  return crypto.randomUUID();
}

function nowISO() {
  return new Date().toISOString();
}

// ============ 鉴权与限流 ============

// 签发登录令牌
function issueToken(userId) {
  const token = crypto.randomBytes(32).toString('hex');
  db.prepare('INSERT INTO tokens (token, user_id, created_at) VALUES (?, ?, ?)').run(token, userId, nowISO());
  return token;
}

// Bearer token 校验中间件：无 token 或 token 无效 → 401
function requireAuth(req, res, next) {
  const m = /^Bearer\s+(.+)$/.exec(req.headers.authorization || '');
  const row = m && db.prepare('SELECT user_id FROM tokens WHERE token = ?').get(m[1]);
  if (!row) return res.status(401).json({ error: '未登录或登录已过期' });
  req.authUserId = row.user_id;
  next();
}

// 请求中的 userId 必须与 token 归属一致，防止冒充他人读写数据
function assertSelf(req, res, userId) {
  if (!userId || userId !== req.authUserId) {
    res.status(403).json({ error: '无权操作他人数据' });
    return false;
  }
  return true;
}

// 简易限流（单进程内存版）：防暴力破解密码与批量注册
const rateBuckets = new Map();
function rateLimit(scope, limit, windowMs) {
  return (req, res, next) => {
    const now = Date.now();
    const key = `${scope}:${req.ip}`;
    const hits = (rateBuckets.get(key) || []).filter(t => now - t < windowMs);
    if (hits.length >= limit) {
      return res.status(429).json({ error: '尝试过于频繁，请稍后再试' });
    }
    hits.push(now);
    rateBuckets.set(key, hits);
    next();
  };
}

// 将数据库行转换为展览对象（JSON 字段解析）
function rowToExhibition(row) {
  return {
    id: row.id,
    userId: row.user_id,
    userName: row.user_name,
    name: row.name,
    introduction: row.introduction,
    startDate: row.start_date,
    endDate: row.end_date,
    firstPictureURL: row.first_picture_url,
    paintingURLs: JSON.parse(row.painting_urls),
    paintingIntroductions: JSON.parse(row.painting_introductions),
    timestamp: row.timestamp,
  };
}

function rowToTravelIdea(row) {
  return {
    id: row.id,
    userId: row.user_id,
    userName: row.user_name,
    title: row.title,
    content: row.content,
    destination: row.destination,
    landmark: row.landmark,
    date: row.date,
    startDate: row.start_date,
    endDate: row.end_date,
    timestamp: row.timestamp,
  };
}

// ============ OSS 图片上传 ============

app.post('/upload-image', requireAuth, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Missing image file' });

    // 魔数校验真实格式（不信任客户端声明的 ext）：xlsx 等非图片一律拒绝
    const realExt = sniffImageType(req.file.buffer);
    if (!realExt) {
      return res.status(400).json({ error: '仅支持 JPG、PNG、GIF、WebP、HEIC 图片' });
    }

    const url = await uploadImage(req.file.buffer, realExt);

    // 内容安全审核移至发布展览时执行（/exhibitions POST），上传阶段不再审查
    res.status(201).json({ url });
  } catch (err) {
    console.error('[OSS] Upload failed:', err.message);
    res.status(500).json({ error: 'Upload failed' });
  }
});

// ============ Support 公开页（Apple App Store Support URL） ============

app.get('/support', (req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Days OFF · 支持</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "PingFang SC", -apple-system, sans-serif;
    background: rgb(250, 246, 236);
    color: rgb(60, 55, 50);
    min-height: 100vh;
    display: flex; justify-content: center;
    padding: 48px 20px;
  }
  .card {
    background: rgb(252, 252, 249);
    border-radius: 14px;
    padding: 36px 32px;
    max-width: 520px; width: 100%;
    box-shadow: 0 2px 12px rgba(120, 100, 80, 0.08);
  }
  h1 {
    font-size: 22px; font-weight: 600;
    color: rgb(128, 0, 32);
    margin-bottom: 4px;
  }
  .subtitle { font-size: 13px; color: rgb(140, 130, 120); margin-bottom: 24px; }
  .section { margin-bottom: 22px; }
  .section h2 { font-size: 15px; font-weight: 600; margin-bottom: 8px; }
  .section p, .section li { font-size: 14px; line-height: 1.7; color: rgb(80, 75, 70); }
  a { color: rgb(128, 0, 32); text-decoration: none; }
  a:hover { text-decoration: underline; }
  .email-box {
    background: rgb(245, 240, 230);
    border-radius: 10px;
    padding: 14px 18px;
    font-size: 15px;
    word-break: break-all;
  }
  ul { padding-left: 20px; }
  .footer {
    margin-top: 28px; padding-top: 18px;
    border-top: 1px solid rgb(230, 222, 208);
    font-size: 12px; color: rgb(160, 150, 140); text-align: center;
  }
</style>
</head>
<body>
  <div class="card">
    <h1>Days OFF</h1>
    <div class="subtitle">App Support · 开发者支持</div>

    <div class="section">
      <h2>联系我们</h2>
      <p>遇到问题或有建议，欢迎通过以下方式与我们联系：</p>
      <div class="email-box" style="margin-top:10px">
        📧 邮箱：<a href="mailto:support@daysoff-app.com">support@daysoff-app.com</a>
      </div>
      <p style="margin-top:10px;font-size:13px;color:rgb(140,130,120)">
        我们会在 1–2 个工作日内回复您的邮件。
      </p>
    </div>

    <div class="section">
      <h2>常见问题</h2>
      <ul>
        <li>注册/登录问题：请检查用户名（2–10 字符，首字为中文或字母）与网络连接。</li>
        <li>画展上传失败：请确认图片为 JPG/PNG/GIF/WebP/HEIC 且单张不超过 10MB。</li>
        <li>数据同步问题：请确保已登录账号并保持网络通畅。</li>
        <li>账号注销：可在「我的 → 设置 → 账号注销」中操作，注销后数据不可恢复。</li>
      </ul>
    </div>

    <div class="footer">
      Days OFF · © 2026 DaysOff Team<br>
      App Store Support URL
    </div>
  </div>
</body>
</html>`);
});

// ============ Privacy Policy 公开页（Apple App Store Privacy Policy URL） ============

app.get('/privacy', (req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Days OFF · Privacy Policy</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "PingFang SC", -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
    background: rgb(250, 246, 236);
    color: rgb(60, 55, 50);
    min-height: 100vh;
    display: flex; justify-content: center;
    padding: 48px 20px;
  }
  .card {
    background: rgb(252, 252, 249);
    border-radius: 14px;
    padding: 36px 32px;
    max-width: 680px; width: 100%;
    box-shadow: 0 2px 12px rgba(120, 100, 80, 0.08);
  }
  h1 {
    font-size: 22px; font-weight: 600;
    color: rgb(128, 0, 32);
    margin-bottom: 4px;
  }
  .subtitle { font-size: 13px; color: rgb(140, 130, 120); margin-bottom: 16px; }
  .lang-switch {
    display: inline-flex;
    background: rgb(245, 240, 230);
    border-radius: 8px;
    padding: 3px;
    font-size: 13px;
    margin-bottom: 24px;
  }
  .lang-switch button {
    border: none;
    background: transparent;
    padding: 6px 14px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    color: rgb(80, 75, 70);
    font-family: inherit;
  }
  .lang-switch button.active {
    background: rgb(252, 252, 249);
    color: rgb(128, 0, 32);
    font-weight: 600;
    box-shadow: 0 1px 3px rgba(120, 100, 80, 0.15);
  }
  .lang-body { display: none; }
  .lang-body.active { display: block; }
  h2 {
    font-size: 15px; font-weight: 600;
    color: rgb(128, 0, 32);
    margin: 20px 0 8px;
  }
  h3 {
    font-size: 14px; font-weight: 600;
    margin: 14px 0 6px;
    color: rgb(60, 55, 50);
  }
  p, li { font-size: 14px; line-height: 1.75; color: rgb(80, 75, 70); }
  ul, ol { padding-left: 22px; margin: 6px 0; }
  li { margin-bottom: 4px; }
  a { color: rgb(128, 0, 32); text-decoration: none; }
  a:hover { text-decoration: underline; }
  .intro { font-size: 14px; color: rgb(80, 75, 70); line-height: 1.75; }
  .footer {
    margin-top: 32px; padding-top: 18px;
    border-top: 1px solid rgb(230, 222, 208);
    font-size: 12px; color: rgb(160, 150, 140); text-align: center;
    line-height: 1.6;
  }
</style>
</head>
<body>
  <div class="card">
    <h1>Days OFF</h1>
    <div class="subtitle" id="subEn">Privacy Policy · Effective August 21, 2026</div>
    <div class="subtitle" id="subZh" style="display:none">隐私政策 · 生效日期：2026年8月21日</div>

    <div class="lang-switch">
      <button id="btnEn" class="active" onclick="switchLang('en')">English</button>
      <button id="btnZh" onclick="switchLang('zh')">中文</button>
    </div>

    <!-- ============ ENGLISH VERSION ============ -->
    <div id="bodyEn" class="lang-body active">
      <p class="intro">
        Welcome to Days OFF ("the App"). We deeply value your privacy.
        Please read this Policy carefully before using the App.
      </p>

      <h2>1. Information We Collect</h2>
      <h3>1.1 Information you provide voluntarily</h3>
      <ul>
        <li><b>Account username</b> — chosen by you at sign-up (2–10 characters, starting with Chinese or a letter).</li>
        <li><b>Password</b> — stored on the server only as a one-way SHA-256 salted hash. We never see or store your plain-text password, and cannot recover it.</li>
      </ul>
      <h3>1.2 Content you create</h3>
      <ul>
        <li>Mood diary entries</li>
        <li>Sports notes and sport training plans</li>
        <li>Travel idea cards, trip cards</li>
        <li>Event cards &amp; milestone cards</li>
        <li>Original artworks you upload (unpublished)</li>
        <li>Exhibitions and travel inspirations you publish publicly</li>
      </ul>
      <h3>1.3 Anonymous statistics</h3>
      <ul>
        <li>Registration count, daily active users</li>
        <li>Crash reports, network error summaries</li>
        <li>Screen-view usage (anonymous)</li>
      </ul>
      <p>All statistics are aggregated anonymously and <b>cannot identify you personally</b>.</p>

      <h2>2. End-to-End Encryption (E2EE)</h2>
      <p>
        Your private content — mood diary, sports notes &amp; plans, travel cards,
        event cards, and unpublished artworks — is encrypted on <b>your device</b>
        using a cryptographic key derived from your password, and only then
        uploaded to our cloud.
      </p>
      <ul>
        <li>The server stores encrypted ciphertext only.</li>
        <li>No one, including the DaysOFF team, can read these contents.</li>
        <li>The encryption key is derived <b>only from your password, only on your device</b>.</li>
        <li>We cannot retrieve or reset this key. If you forget your password,
            encrypted content cannot be recovered. Please keep your password safe.</li>
      </ul>

      <h2>3. Public Content</h2>
      <p>
        Content you publish publicly — exhibitions, travel inspirations, and
        shared artworks — is stored in clear text on the server and visible to
        other users, to enable our legal content moderation obligations.
      </p>
      <p style="color:rgb(180,70,60)">
        ⚠ Please do <b>not</b> include sensitive personal information in public content.
      </p>

      <h2>4. How We Use Information</h2>
      <ol>
        <li>Providing and maintaining the App service, including multi-device cloud sync.</li>
        <li>Improving and optimizing the product experience.</li>
        <li>Protecting account and data security, and complying with legal obligations
            such as illegal content reporting.</li>
      </ol>
      <p>We <b>do not</b> use your data for advertising, user profiling, or resale.</p>

      <h2>5. Data Storage</h2>
      <ul>
        <li>Your data lives on your device's local storage or on our secure servers (HTTPS, TLS 1.2+).</li>
        <li>Private content is always stored as encrypted ciphertext.</li>
        <li>Data is retained for the shortest period necessary to fulfill the purposes described in this Policy.</li>
      </ul>

      <h2>6. Data Sharing &amp; Disclosure</h2>
      <ul>
        <li>We <b>never sell</b> your personal information to any third party.</li>
        <li>We only share or disclose your information when:
          <ol>
            <li>We have obtained your explicit informed consent.</li>
            <li>Required by laws, regulations, valid court orders, or government requests.</li>
          </ol>
        </li>
      </ul>

      <h2>7. Data Security</h2>
      <p>
        We employ reasonable administrative and technical measures to protect your
        information, including:
      </p>
      <ul>
        <li>HTTPS / TLS 1.2+ for every network request.</li>
        <li>SHA-256 one-way hash for passwords (with static salt).</li>
        <li>E2EE for all private user content.</li>
        <li>Bearer-token authentication for all write &amp; private-read APIs.</li>
        <li>IP-based rate limiting for registration &amp; login endpoints.</li>
      </ul>

      <h2>8. Your Rights</h2>
      <ul>
        <li><b>Access</b> &amp; <b>Correct</b> your personal information within the App.</li>
        <li><b>Export</b> your data: content is also stored locally in UserDefaults and on the server synced under your account.</li>
        <li><b>Delete</b> specific content in each module.</li>
        <li><b>Account deletion</b> (Guideline 5.1.1(v)):
          Go to <i>Me → Settings → Delete Account</i>. Your account and all data
          (user, tokens, exhibitions, travel ideas, feedback, user_data,
          block records, uploaded images on OSS) are permanently wiped from
          our servers in one atomic transaction and cannot be recovered.</li>
        <li><b>Log out</b> locally at any time in <i>Me → Settings</i>.</li>
      </ul>
      <p>To exercise any other privacy right, contact us at the address below.</p>

      <h2>9. Children's Privacy</h2>
      <p>
        The App is <b>not directed at children under 14 years of age</b>.
        We do not knowingly collect personal information from children under 14.
        If you believe we have done so, please contact us immediately and we will
        delete the information promptly.
      </p>

      <h2>10. Policy Updates</h2>
      <p>
        We may revise this Policy from time to time. Updates are posted on this
        page with the revised effective date; material changes are notified
        prominently.
      </p>

      <h2>11. Contact Us</h2>
      <p>
        For any questions, requests, or complaints about this Policy or our
        privacy practices, email:
      </p>
      <p style="margin-top:8px; background:rgb(245,240,230); border-radius:10px; padding:14px 18px; font-size:15px">
        📧 <a href="mailto:support@daysoff-app.com">support@daysoff-app.com</a>
      </p>
    </div>

    <!-- ============ CHINESE VERSION ============ -->
    <div id="bodyZh" class="lang-body">
      <p class="intro">
        欢迎使用 Days OFF（以下简称「本应用」）。我们非常重视您的隐私保护，请您在使用本应用前仔细阅读本政策。
      </p>

      <h2>一、我们收集的信息</h2>
      <h3>1. 您主动提供的信息</h3>
      <ul>
        <li><b>用户名</b>：您注册时自行设定（2–10 字符，首字必须为中文或英文字母）。</li>
        <li><b>密码</b>：服务器端仅存储带盐 SHA-256 不可逆哈希值。我们不会也无法获知您的明文密码，无法重置加密内容。</li>
      </ul>
      <h3>2. 您创作的内容</h3>
      <ul>
        <li>心情手记</li>
        <li>运动笔记、运动计划</li>
        <li>旅行灵感卡片、打包的旅行卡</li>
        <li>赛事卡片、里程碑卡片</li>
        <li>未公开的原创作品（上传但未发布）</li>
        <li>您发布的公开展览、公开旅行灵感</li>
      </ul>
      <h3>3. 匿名统计信息</h3>
      <ul>
        <li>注册数量、每日活跃用户</li>
        <li>异常退出、网络错误汇总</li>
        <li>各页面浏览统计（匿名）</li>
      </ul>
      <p>所有统计数据均为匿名聚合，<b>无法识别您的个人身份</b>。</p>

      <h2>二、端到端加密</h2>
      <p>
        您的私密内容——心情手记、运动笔记与运动计划、旅行卡片、
        赛事卡片及未公开的作品——均在<b>您的设备上</b>使用由您的密码派生的
        密钥加密后才上传云端。
      </p>
      <ul>
        <li>服务器仅存储加密后的密文。</li>
        <li>包括我们在内的任何人都无法查看这些内容。</li>
        <li>加密密钥<b>仅从您的密码、仅在您的设备上派生</b>。</li>
        <li>我们无法获知或重置该密钥。若您忘记密码，上述加密内容
            将无法恢复，请妥善保管密码。</li>
      </ul>

      <h2>三、公开内容</h2>
      <p>
        您主动发布的展览、旅行灵感及公开作品，以明文形式存储并对其他用户展示，
        以便我们依法履行内容审核义务。
      </p>
      <p style="color:rgb(180,70,60)">
        ⚠ 请您勿在公开内容中填写任何个人敏感信息。
      </p>

      <h2>四、信息的使用</h2>
      <ol>
        <li>提供与维护本应用服务（包括多设备云同步）。</li>
        <li>改进和优化产品体验。</li>
        <li>保障账号与数据安全、配合合法内容审核要求。</li>
      </ol>
      <p>我们<b>不会</b>将您的数据用于广告、用户画像或转售。</p>

      <h2>五、信息的存储</h2>
      <ul>
        <li>存储位置：您的设备本地或我们托管的安全服务器（HTTPS，TLS 1.2+）。</li>
        <li>私密内容始终以密文形式存储。</li>
        <li>保存期限：为实现本政策目的所必需的最短时间。</li>
      </ul>

      <h2>六、信息的共享与披露</h2>
      <ul>
        <li>我们<b>不会向任何第三方出售</b>您的个人信息。</li>
        <li>仅在以下情形共享或披露：
          <ol>
            <li>取得您明确的知情同意。</li>
            <li>法律法规、有效司法裁定或政府机关的合规要求。</li>
          </ol>
        </li>
      </ul>

      <h2>七、信息安全</h2>
      <p>我们采取合理的管理与技术措施保护您的信息，包括但不限于：</p>
      <ul>
        <li>全站 HTTPS / TLS 1.2+ 加密传输。</li>
        <li>密码采用带盐 SHA-256 单向哈希存储。</li>
        <li>所有私密内容均采用端到端加密。</li>
        <li>所有写入 / 私密读取接口均采用 Bearer Token 鉴权。</li>
        <li>注册 / 登录接口采用基于 IP 的速率限制，防止暴力破解。</li>
      </ul>

      <h2>八、您的权利</h2>
      <ul>
        <li><b>访问</b> 与 <b>更正</b>：您可在应用内各模块直接访问或更正您的个人信息。</li>
        <li><b>导出</b>：数据同时存储在您的设备本地 UserDefaults 及您账号下的服务器中。</li>
        <li><b>删除</b>：可在各模块删除特定内容。</li>
        <li><b>账号注销</b>（符合 App Store 指引 5.1.1(v)）：前往「我的 → 设置 → 账号注销」。
          您的账号及全部数据（用户、令牌、展览、旅行灵感、留言、数据块、拉黑记录、
          OSS 上传的图片）将以事务方式一次性永久从服务器删除，无法恢复。</li>
        <li><b>退出登录</b>：随时在「我的 → 设置」中清除本地登录态。</li>
      </ul>
      <p>如需行使其他隐私权，请通过以下邮箱联系我们。</p>

      <h2>九、未成年人保护</h2>
      <p>
        本应用<b>不面向十四周岁以下儿童</b>提供服务。我们不会故意收集
        十四周岁以下儿童的个人信息。若您认为我们不慎收集了此类信息，
        请立即联系我们，我们会及时删除。
      </p>

      <h2>十、政策更新</h2>
      <p>
        我们可能适时修订本政策。更新版本会在本页面公布并注明新的生效日期；
        重大变更将以显著方式通知您。
      </p>

      <h2>十一、联系我们</h2>
      <p>
        如对本政策有任何疑问、请求或投诉，可通过以下邮箱联系我们：
      </p>
      <p style="margin-top:8px; background:rgb(245,240,230); border-radius:10px; padding:14px 18px; font-size:15px">
        📧 <a href="mailto:support@daysoff-app.com">support@daysoff-app.com</a>
      </p>
    </div>

    <div class="footer">
      Days OFF · © 2026 DaysOff Team<br>
      App Store Privacy Policy URL · <a href="/support">Support</a>
    </div>
  </div>

<script>
function switchLang(lang) {
  document.getElementById('bodyEn').classList.toggle('active', lang === 'en');
  document.getElementById('bodyZh').classList.toggle('active', lang === 'zh');
  document.getElementById('subEn').style.display   = lang === 'en' ? 'block' : 'none';
  document.getElementById('subZh').style.display   = lang === 'zh' ? 'block' : 'none';
  document.getElementById('btnEn').classList.toggle('active', lang === 'en');
  document.getElementById('btnZh').classList.toggle('active', lang === 'zh');
  document.documentElement.lang = lang === 'zh' ? 'zh-CN' : 'en';
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
</script>
</body>
</html>`);
});

// ============ 展览 ============

// GET /exhibitions?userId=xxx — 获取展览列表（过滤被拉黑用户的展览）
app.get('/exhibitions', (req, res) => {
  try {
    const exhibitions = db.prepare('SELECT * FROM exhibitions ORDER BY timestamp DESC').all();

    let blockedIds = [];
    if (req.query.userId) {
      const rows = db.prepare('SELECT blocked_user_id FROM block_list WHERE blocker_user_id = ?').all(req.query.userId);
      blockedIds = rows.map(r => r.blocked_user_id);
    }

    const result = exhibitions
      .filter(e => !blockedIds.includes(e.user_id))
      .map(rowToExhibition);

    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// POST /exhibitions — 创建/更新展览（去重：同 id 或同 userId+name）
// 发布时对所有图片执行内容安全审核；未发布的上传图片不审查
app.post('/exhibitions', requireAuth, async (req, res) => {
  try {
    const { id, userId, userName, name, introduction, startDate, endDate, firstPictureURL, paintingURLs, paintingIntroductions } = req.body;
    if (!assertSelf(req, res, userId)) return;

    // 内容安全审核：首图 + 所有画作图片
    const urlsToCheck = [firstPictureURL, ...(paintingURLs || [])].filter(Boolean);
    for (const url of urlsToCheck) {
      const verdict = await moderateImage(url);
      if (!verdict.pass) {
        // 命中违规 → 删除该 OSS 对象并拒绝发布
        await deleteImage(url).catch(() => {});
        return res.status(422).json({ error: '图片包含违规内容，无法发布' });
      }
    }

    const exhibitionId = id || uuid();
    const ts = nowISO();

    // 去重：同 id 或同 userId + name 则先删后插
    db.prepare('DELETE FROM exhibitions WHERE id = ? OR (user_id = ? AND name = ?)').run(exhibitionId, userId, name);

    db.prepare(`
      INSERT INTO exhibitions (id, user_id, user_name, name, introduction, start_date, end_date, first_picture_url, painting_urls, painting_introductions, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      exhibitionId, userId, userName, name, introduction, startDate, endDate,
      firstPictureURL || null,
      JSON.stringify(paintingURLs || []),
      JSON.stringify(paintingIntroductions || []),
      ts
    );

    const row = db.prepare('SELECT * FROM exhibitions WHERE id = ?').get(exhibitionId);
    res.status(201).json(rowToExhibition(row));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 举报 ============

// POST /exhibitions/report — 举报展览（≥3 次自动删除）
app.post('/exhibitions/report', requireAuth, (req, res) => {
  try {
    const { exhibitionId, reporterUserId, reason } = req.body;
    if (!assertSelf(req, res, reporterUserId)) return;
    const reportId = uuid();
    const ts = nowISO();

    db.prepare('INSERT INTO exhibition_reports (id, exhibition_id, reporter_user_id, reason, timestamp) VALUES (?, ?, ?, ?, ?)')
      .run(reportId, exhibitionId, reporterUserId, reason, ts);

    const { count } = db.prepare('SELECT COUNT(*) as count FROM exhibition_reports WHERE exhibition_id = ?').get(exhibitionId);

    if (count >= 3) {
      db.prepare('DELETE FROM exhibitions WHERE id = ?').run(exhibitionId);
    }

    res.json({
      success: true,
      message: count >= 3 ? '展览已被移除' : '举报已提交',
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 拉黑 ============

// POST /users/block — 拉黑用户（避免重复）
app.post('/users/block', requireAuth, (req, res) => {
  try {
    const { blockerUserId, blockedUserId } = req.body;
    if (!assertSelf(req, res, blockerUserId)) return;
    db.prepare('INSERT OR IGNORE INTO block_list (blocker_user_id, blocked_user_id) VALUES (?, ?)')
      .run(blockerUserId, blockedUserId);
    res.json({ success: true, message: '已拉黑该用户' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 用户注册/登录 ============

const PASSWORD_SALT = 'TheApp_2026_salt';

function hashPassword(password) {
  return crypto.createHash('sha256').update(PASSWORD_SALT + password).digest('hex');
}

// POST /users/register — 注册新用户
app.post('/users/register', rateLimit('register', 5, 60 * 60 * 1000), (req, res) => {
  try {
    const { username: rawUsername, password } = req.body;
    // 首尾去空格；用户名大小写不敏感，存储原始大小写用于展示
    const username = (rawUsername || '').trim();
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }
    // 用户名规则：2–10 字符，首字必须是中文或英文字母
    if (!/^[\u4e00-\u9fa5a-zA-Z][\u4e00-\u9fa5a-zA-Z0-9_]{1,9}$/.test(username)) {
      return res.status(400).json({ error: '用户名 2–10 字符，首字必须是中文或英文字母' });
    }
    // 密码规则：8–16 字符，至少包含 1 个数字和 1 个字母
    if (!/^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,16}$/.test(password)) {
      return res.status(400).json({ error: '密码 8–16 字符，至少包含 1 个数字和 1 个字母' });
    }
    // 检查用户名是否已存在（大小写不敏感：Apple / apple / APPLE 视为同一账号）
    const existing = db.prepare('SELECT id FROM users WHERE LOWER(username) = LOWER(?)').get(username);
    if (existing) {
      return res.status(409).json({ error: '该用户名已被注册' });
    }
    const id = uuid();
    const hash = hashPassword(password);
    const createdAt = nowISO();
    db.prepare('INSERT INTO users (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)')
      .run(id, username, hash, createdAt);
    res.status(201).json({ userId: id, username, token: issueToken(id) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// POST /users/login — 用户登录
app.post('/users/login', rateLimit('login', 10, 5 * 60 * 1000), (req, res) => {
  try {
    const { username: rawUsername, password } = req.body;
    const username = (rawUsername || '').trim();
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }
    // 大小写不敏感：用任意大小写组合都能登录
    const user = db.prepare('SELECT id, username, password_hash FROM users WHERE LOWER(username) = LOWER(?)').get(username);
    if (!user) {
      return res.status(404).json({ error: '该账号不存在，请先注册' });
    }
    const hash = hashPassword(password);
    if (hash !== user.password_hash) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }
    res.json({ userId: user.id, username: user.username, token: issueToken(user.id) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 旅行灵感 ============

// GET /travel-ideas — 获取所有旅行灵感
app.get('/travel-ideas', (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM travel_ideas ORDER BY timestamp DESC').all();
    res.json(rows.map(rowToTravelIdea));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// POST /travel-ideas — 同步旅行灵感（全量替换该用户的灵感）
app.post('/travel-ideas', requireAuth, (req, res) => {
  try {
    const { userId, userName, ideas } = req.body;
    if (!assertSelf(req, res, userId)) return;
    const now = nowISO();

    // 删除该用户旧数据
    db.prepare('DELETE FROM travel_ideas WHERE user_id = ?').run(userId);

    // 插入新数据
    const insert = db.prepare(`
      INSERT INTO travel_ideas (id, user_id, user_name, title, content, destination, landmark, date, start_date, end_date, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    for (const idea of ideas) {
      insert.run(
        idea.id || uuid(), userId, userName,
        idea.title, idea.content, idea.destination, idea.landmark, idea.date,
        idea.startDate || null, idea.endDate || null, now
      );
    }

    const rows = db.prepare('SELECT * FROM travel_ideas ORDER BY timestamp DESC').all();
    res.json(rows.map(rowToTravelIdea));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 用户数据云同步（通用数据块） ============

// 允许的 key 白名单，防止任意写入
const USER_DATA_KEYS = new Set([
  'works',            // 上传作品（图片为 OSS URL）
  'sports_plans',     // 运动计划
  'sports_diary',     // 运动日记
  'sports_cell_texts',// 运动笔记热身流程/练习日常/整理放松 三格文字
  'sports_trophies',  // 运动奖杯（里程碑）
  'mood_diary',       // 心情手记（信封）
  'packed_trips',     // 已打包旅行卡片
  'events_matches',   // 赛事卡片
  'milestones',       // 运动里程碑（含日期/描述）
  'card_positions',   // 我的页面所有卡片的位置/旋转
]);

// GET /user-data/:userId — 拉取该用户全部数据块 { key: value, ... }
app.get('/user-data/:userId', requireAuth, (req, res) => {
  try {
    if (!assertSelf(req, res, req.params.userId)) return;
    const rows = db.prepare('SELECT data_key, json FROM user_data WHERE user_id = ?').all(req.params.userId);
    const result = {};
    for (const row of rows) {
      try { result[row.data_key] = JSON.parse(row.json); } catch (_) { /* 跳过损坏数据 */ }
    }
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// PUT /user-data/:userId/:key — 全量覆盖该用户的某个数据块
app.put('/user-data/:userId/:key', requireAuth, (req, res) => {
  try {
    const { userId, key } = req.params;
    if (!assertSelf(req, res, userId)) return;
    if (!USER_DATA_KEYS.has(key)) {
      return res.status(400).json({ error: '未知的 data key' });
    }
    const value = req.body.value;
    if (value === undefined) {
      return res.status(400).json({ error: '缺少 value 字段' });
    }
    db.prepare(`
      INSERT INTO user_data (user_id, data_key, json, updated_at) VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, data_key) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
    `).run(userId, key, JSON.stringify(value), nowISO());
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 启动 ============

// ============ 匿名统计（注册数 / 日活）============

// 统计查询口令：必须通过环境变量 ADMIN_KEY 配置；未配置时一律拒绝（fail-closed，无代码兜底）
const ADMIN_KEY = process.env.ADMIN_KEY || '';
const STATS_SALT = 'daysoff_stats_2026_salt';

// 服务器本地日期（UTC+8 机房）：YYYY-MM-DD
function todayLocal() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// 活跃上报：App 登录/启动时调用；userId 哈希后存储，同一天同一用户只记一次
app.post('/stats/ping', (req, res) => {
  try {
    const userId = String((req.body && req.body.userId) || '');
    if (!userId) return res.status(400).json({ error: '缺少 userId' });
    const userHash = crypto.createHash('sha256').update(userId + STATS_SALT).digest('hex');
    db.prepare('INSERT OR IGNORE INTO daily_active (day, user_hash) VALUES (?, ?)').run(todayLocal(), userHash);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// 统计查询：注册总数 + 今日活跃 + 近 30 天日活（需口令，只含数字不含任何用户信息）
app.get('/stats/summary', (req, res) => {
  try {
    if (!ADMIN_KEY || req.query.key !== ADMIN_KEY) return res.status(403).json({ error: '无权限' });
    const totalUsers = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
    const todayActive = db.prepare('SELECT COUNT(*) AS c FROM daily_active WHERE day = ?').get(todayLocal()).c;
    const daily = db.prepare(
      'SELECT day, COUNT(*) AS count FROM daily_active GROUP BY day ORDER BY day DESC LIMIT 30'
    ).all();
    res.json({ totalUsers, todayActive, daily });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 匿名运行事件（异常退出 / 网络错误）============

const EVENT_TYPES = new Set(['abnormal_exit', 'network_error']);

// 事件上报：异常退出（附带上次最后停留界面）与网络错误
app.post('/stats/event', (req, res) => {
  try {
    const { type, screen, detail, userId } = req.body || {};
    if (!EVENT_TYPES.has(type)) return res.status(400).json({ error: '未知事件类型' });
    const userHash = userId
      ? crypto.createHash('sha256').update(String(userId) + STATS_SALT).digest('hex')
      : null;
    db.prepare(
      'INSERT INTO app_events (id, day, type, screen, detail, user_hash, ts) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).run(uuid(), todayLocal(), type, String(screen || '').slice(0, 60), String(detail || '').slice(0, 200), userHash, nowISO());
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// 事件查询：按类型/界面聚合 + 最近 50 条明细（需口令；明细不含用户标识）
app.get('/stats/events', (req, res) => {
  try {
    if (!ADMIN_KEY || req.query.key !== ADMIN_KEY) return res.status(403).json({ error: '无权限' });
    const byType = db.prepare('SELECT type, COUNT(*) AS count FROM app_events GROUP BY type').all();
    const byScreen = db.prepare(
      'SELECT type, screen, COUNT(*) AS count FROM app_events GROUP BY type, screen ORDER BY count DESC'
    ).all();
    const recent = db.prepare(
      'SELECT ts, type, screen, detail FROM app_events ORDER BY ts DESC LIMIT 50'
    ).all();
    res.json({ byType, byScreen, recent });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// 可视化运营后台页面（数据接口均有口令保护，页面本身无需保密）
app.get('/admin', (req, res) => {
  res.sendFile(require('path').join(__dirname, 'admin.html'));
});

// ============ 用户留言反馈 ============

// POST /feedback — 提交留言（需登录）
app.post('/feedback', requireAuth, (req, res) => {
  try {
    const { email, message } = req.body;
    if (!email || !message || !email.trim() || !message.trim()) {
      return res.status(400).json({ error: '邮箱和留言不能为空' });
    }
    // 邮箱格式校验
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      return res.status(400).json({ error: '邮箱格式不正确' });
    }
    // 从 users 表查用户名
    const userRow = db.prepare('SELECT username FROM users WHERE id = ?').get(req.authUserId);
    const username = userRow ? userRow.username : '';
    const id = uuid();
    const ts = nowISO();
    db.prepare('INSERT INTO feedback (id, user_id, username, email, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)')
      .run(id, req.authUserId, username, email.trim(), message.trim(), ts);
    res.status(201).json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// GET /feedback — 查看所有留言（需 ADMIN_KEY）
app.get('/feedback', (req, res) => {
  try {
    if (!ADMIN_KEY || req.query.key !== ADMIN_KEY) return res.status(403).json({ error: '无权限' });
    const rows = db.prepare('SELECT * FROM feedback ORDER BY timestamp DESC').all();
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ============ 账号注销 ============

// DELETE /users/me — 注销当前登录账号，删除该用户在服务器上的全部数据
// 需登录；可选 body.reason 记录注销原因
app.delete('/users/me', requireAuth, (req, res) => {
  const uid = req.authUserId;
  try {
    // 使用事务，保证删除要么全部成功要么全部回滚
    // 事务内先抓取 OSS 图片 URL，事务外异步删除远端文件
    const tx = db.transaction(() => {
      const exhibitions = db.prepare('SELECT first_picture_url, painting_urls FROM exhibitions WHERE user_id = ?').all(uid);
      // 删除该用户发布的展览
      db.prepare('DELETE FROM exhibitions WHERE user_id = ?').run(uid);
      // 删除该用户提交的展览举报记录
      db.prepare('DELETE FROM exhibition_reports WHERE reporter_user_id = ?').run(uid);
      // 删除该用户的旅行灵感
      db.prepare('DELETE FROM travel_ideas WHERE user_id = ?').run(uid);
      // 删除该用户参与的拉黑关系（作为拉黑者或被拉黑者）
      db.prepare('DELETE FROM block_list WHERE blocker_user_id = ? OR blocked_user_id = ?').run(uid, uid);
      // 删除该用户的所有数据块
      db.prepare('DELETE FROM user_data WHERE user_id = ?').run(uid);
      // 删除该用户的留言反馈
      db.prepare('DELETE FROM feedback WHERE user_id = ?').run(uid);
      // 删除该用户的所有登录令牌（强制下线）
      db.prepare('DELETE FROM tokens WHERE user_id = ?').run(uid);
      // 最后删除用户主记录
      db.prepare('DELETE FROM users WHERE id = ?').run(uid);
      return exhibitions;
    });
    const exhibitions = tx();

    // 事务外异步清理 OSS 上的画展图片（失败不阻塞响应）
    const urls = [];
    for (const row of exhibitions) {
      if (row.first_picture_url) urls.push(row.first_picture_url);
      try {
        const arr = JSON.parse(row.painting_urls || '[]');
        if (Array.isArray(arr)) urls.push(...arr.filter(Boolean));
      } catch (_) {}
    }
    for (const url of urls) {
      deleteImage(url).catch(() => {});
    }

    res.json({ success: true });
  } catch (err) {
    console.error('[Delete account] failed:', err.message);
    res.status(500).json({ error: '注销失败，请稍后再试' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[DaysOff Backend] Running on http://0.0.0.0:${PORT}`);
});
