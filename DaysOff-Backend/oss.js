const OSS = require('ali-oss');
const path = require('path');
const crypto = require('crypto');

const client = new OSS({
  region: process.env.OSS_REGION || 'oss-cn-hangzhou',
  accessKeyId: process.env.OSS_ACCESS_KEY_ID,
  accessKeySecret: process.env.OSS_ACCESS_KEY_SECRET,
  bucket: process.env.OSS_BUCKET || 'daysoff-app',
});

/**
 * 上传图片到 OSS，返回公共访问 URL
 * @param {Buffer} buffer - 图片二进制数据
 * @param {string} ext - 文件扩展名，如 'jpg'、'png'
 * @returns {Promise<string>} 公共访问 URL
 */
async function uploadImage(buffer, ext = 'jpg') {
  // 生成唯一文件名：exhibitions/2026-08/abcdef.jpg
  const now = new Date();
  const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const randomName = crypto.randomBytes(8).toString('hex');
  const objectKey = `exhibitions/${month}/${randomName}.${ext}`;

  await client.put(objectKey, buffer);

  // 公共读 Bucket，直接拼接 URL
  return `https://${process.env.OSS_BUCKET}.oss-cn-hangzhou.aliyuncs.com/${objectKey}`;
}

/**
 * 按 URL 删除 OSS 对象（违规图片清理用）
 * @param {string} url - uploadImage 返回的完整 URL
 */
async function deleteImage(url) {
  const prefix = `https://${process.env.OSS_BUCKET}.oss-cn-hangzhou.aliyuncs.com/`;
  if (!url || !url.startsWith(prefix)) return;
  await client.delete(url.slice(prefix.length));
}

module.exports = { uploadImage, deleteImage };
