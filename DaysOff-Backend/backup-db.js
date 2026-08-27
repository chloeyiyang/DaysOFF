const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const DB_PATH = process.env.DB_PATH || '/opt/daysoff-backend/daysoff.db';
const BACKUP_DIR = '/opt/daysoff-backups';
const KEEP_DAYS = 7;

// 生成备份文件名：daysoff_YYYYMMDD_HHmmss.db
const now = new Date();
const ts = now.getFullYear() +
  String(now.getMonth() + 1).padStart(2, '0') +
  String(now.getDate()).padStart(2, '0') + '_' +
  String(now.getHours()).padStart(2, '0') +
  String(now.getMinutes()).padStart(2, '0') +
  String(now.getSeconds()).padStart(2, '0');
const backupPath = path.join(BACKUP_DIR, 'daysoff_' + ts + '.db');

// 用 VACUUM INTO 在线热备（WAL 模式下也能拿到一致快照）
const db = new Database(DB_PATH, { readonly: true });
db.exec("VACUUM INTO '" + backupPath + "'");
db.close();

// gzip 压缩
execSync('gzip -f ' + JSON.stringify(backupPath));
const gzPath = backupPath + '.gz';
const size = fs.statSync(gzPath).size;
console.log('备份完成: ' + gzPath + ' (' + (size / 1024).toFixed(1) + ' KB)');

// 清理 KEEP_DAYS 天前的旧备份
const cutoff = new Date(Date.now() - KEEP_DAYS * 24 * 60 * 60 * 1000);
let cleaned = 0;
const files = fs.readdirSync(BACKUP_DIR);
for (const f of files) {
  if (!f.startsWith('daysoff_') || !f.endsWith('.gz')) continue;
  const full = path.join(BACKUP_DIR, f);
  if (fs.statSync(full).mtime < cutoff) {
    fs.unlinkSync(full);
    cleaned++;
  }
}
if (cleaned > 0) console.log('已清理 ' + cleaned + ' 个过期备份');

// 列出当前备份总数
const remaining = files.filter(f => f.endsWith('.gz')).length;
console.log('当前备份总数: ' + remaining + ' (保留 ' + KEEP_DAYS + ' 天)');
