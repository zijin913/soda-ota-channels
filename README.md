# SODA OTA Channels

> 这个目录的三个 .txt 文件是 OTA 通道的"目标版本号",由 `tools/promote.sh` 写,客户机 `ota/update.sh` 定时拉。
>
> 部署方式:**用 GitHub Pages 把这个目录的内容当作静态网站**,客户机走 HTTPS 拉。

## 文件

| 文件 | 客户机用途 | 谁更新 |
|---|---|---|
| `dev.txt` | SOMA 自家机器订阅 —— CI 通过即推 | `promote.sh dev <version>` |
| `canary.txt` | 1-2 台早期客户订阅 —— 人工晋升,canary 跑稳 ≥ 7 天 | `promote.sh canary <version>` |
| `stable.txt` | 全员订阅 —— canary 稳定后晋升 | `promote.sh stable <version>` |

每个文件就一行版本号,如 `0.1`。空文件表示该通道当前不发布(客户机看到空响应,update.sh 静默 skip)。

## 用 GitHub Pages 托管(推荐,最简)

### 一次性设置

1. **建一个 public repo**(不能用 private,GitHub Pages 限制),命名建议 `soda-ota-channels`:

   ```bash
   cd /tmp
   mkdir soda-ota-channels && cd soda-ota-channels
   git init
   git remote add origin https://github.com/zijin913/soda-ota-channels.git
   ```

2. 把 `channels/` 目录里的 `dev.txt` / `canary.txt` / `stable.txt` 拷进来,推上去:

   ```bash
   cp ~/Library/CloudStorage/.../files/secure-robot-app/channels/{dev,canary,stable}.txt .
   git add . && git commit -m "initial channels" && git push -u origin main
   ```

3. **去 GitHub 仓库 Settings → Pages**:
   - Source: `Deploy from a branch`
   - Branch: `main` / `(root)`
   - 保存

   一两分钟后 GitHub 会给你一个 URL,形如:
   ```
   https://zijin913.github.io/soda-ota-channels/
   ```

4. **验证**:
   ```bash
   curl https://zijin913.github.io/soda-ota-channels/dev.txt
   # 应输出: 0.1
   ```

5. **改 update.sh + promote.sh 的 CHANNEL_BASE 默认值**:

   ```bash
   # 在你 macOS 上:
   cd ~/Library/CloudStorage/.../files/secure-robot-app
   sed -i '' "s|https://ota.example.com|https://zijin913.github.io/soda-ota-channels|g" \
     ota/update.sh tools/promote.sh
   ```

### 日常发版本

```bash
# 在你 macOS / 任何能 git push 的机器上
cd /path/to/soda-ota-channels   # 克隆出来一份
./promote.sh dev 0.2            # 修改 dev.txt
                                # promote.sh 自动 git add + commit + push
                                # GitHub Pages 一两分钟后更新
```

客户机的 OTA timer 下次跑(默认每小时)就会拉新版本。

## 备选:用 S3 / 自家 nginx

如果不想用 GitHub Pages(比如内网部署,客户机访问不了 github.io):

- **S3 + CloudFront**:把这三个文件传 S3 桶,通过 CloudFront 暴露 HTTPS。改 `CHANNEL_BASE` 指向 CloudFront 域名。
- **自家 VPS + nginx / Caddy**:静态文件托管,配 HTTPS。
- **Tailscale / 内网**:客户机若都在你 Tailscale 网络里,可以用 HTTP + 私有域名,简化证书。

通道协议本身就一行版本号,任何能 serve 静态文本的 HTTPS 端点都行。
