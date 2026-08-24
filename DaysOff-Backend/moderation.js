// 图片安全：① 魔数校验真实格式 ② 阿里云内容安全 2.0 违规检测（色情/暴恐等）
const Green = require('@alicloud/green20220302');

// ============ 文件类型魔数校验 ============

/**
 * 按文件头魔数识别真实图片格式，不信任客户端声明的 ext。
 * @param {Buffer} buf
 * @returns {'jpg'|'png'|'gif'|'webp'|'heic'|'bmp'|null} 非图片返回 null
 */
function sniffImageType(buf) {
  if (!buf || buf.length < 12) return null;
  // JPEG: FF D8 FF
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'png';
  // GIF: 'GIF8'
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x38) return 'gif';
  // BMP: 'BM'
  if (buf[0] === 0x42 && buf[1] === 0x4d) return 'bmp';
  // WebP: 'RIFF'....'WEBP'
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  // HEIC/HEIF: offset 4 'ftyp' + brand heic/heix/hevc/mif1/msf1
  if (buf.toString('ascii', 4, 8) === 'ftyp') {
    const brand = buf.toString('ascii', 8, 12);
    if (['heic', 'heix', 'hevc', 'mif1', 'msf1'].includes(brand)) return 'heic';
  }
  return null;
}

// ============ 阿里云内容安全（图片审核） ============

let client = null;
function getClient() {
  if (!client) {
    client = new Green.default({
      accessKeyId: process.env.OSS_ACCESS_KEY_ID,
      accessKeySecret: process.env.OSS_ACCESS_KEY_SECRET,
      endpoint: 'green-cip.cn-hangzhou.aliyuncs.com',
    });
  }
  return client;
}

/**
 * 调内容安全 baselineCheck（覆盖色情/暴恐/违禁等基线风险）。
 * @returns {Promise<{pass: boolean, labels: string[], degraded: boolean}>}
 *   pass=false 命中违规；degraded=true 表示审核服务不可用（未开通/超时/异常），
 *   此时放行但已记日志——开通服务后自动生效，无需改代码。
 */
async function moderateImage(imageUrl) {
  try {
    const req = new Green.ImageModerationRequest({
      service: 'baselineCheck',
      serviceParameters: JSON.stringify({ imageUrl }),
    });
    const resp = await getClient().imageModeration(req);
    const body = resp.body || {};

    // 非 200：408=未开通/无权限，403=QPS 超限等 → 降级放行 + 日志
    if (body.code !== 200) {
      console.warn(`[Moderation] degraded: code=${body.code} msg=${body.msg || ''} url=${imageUrl}`);
      return { pass: true, labels: [], degraded: true };
    }

    const data = body.data || {};
    const results = data.result || [];
    const hitLabels = results
      .map(r => r.label)
      .filter(l => l && l !== 'nonLabel');
    const riskLevel = (data.riskLevel || 'none').toLowerCase();

    if (hitLabels.length > 0 || (riskLevel !== 'none' && riskLevel !== '')) {
      console.warn(`[Moderation] REJECT url=${imageUrl} labels=${hitLabels.join(',')} risk=${riskLevel}`);
      return { pass: false, labels: hitLabels, degraded: false };
    }
    return { pass: true, labels: [], degraded: false };
  } catch (err) {
    // 审核服务异常（网络/凭证错误等）→ 降级放行 + 日志，不阻塞正常用户
    console.warn(`[Moderation] degraded: ${err.code || ''} ${(err.message || '').slice(0, 200)}`);
    return { pass: true, labels: [], degraded: true };
  }
}

module.exports = { sniffImageType, moderateImage };
