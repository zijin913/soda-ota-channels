# SODA OTA Channels

> 这个 repo 的两个 `.txt` 文件是 OTA 通道的"目标版本号"。`tools/promote.sh`(在 vendor 的 SOMA 上)写它们,客户机的 `ota/update.sh` 定时拉。
>
> **托管在 GitHub Pages 上**,客户机走 HTTPS 拉。

## 通道

| 文件 | 谁订 | 谁更新 |
|---|---|---|
| `dev.txt` | 只有 vendor 的 SOMA 内部测试机 | `promote.sh dev <version>` |
| `stable.txt` | 所有外部用户(IF + 终端客户) | `promote.sh stable <version>`(dev 上 soak ≥ 7 天后) |

每个文件就一行版本号,比如 `0.19`。空文件 = 这个通道当前不发布(客户机看到空响应,update.sh 静默 skip)。

## 发版流程

vendor 在 SOMA 上:

```bash
ssh SOMA
cd ~/Projects/soda-bimanual

# 1. build + push 镜像到 ghcr
REGISTRY=ghcr.io/somarobotics ROBOT_VERSION=0.X docker compose build
REGISTRY=ghcr.io/somarobotics ROBOT_VERSION=0.X docker compose push

# 2. 推到 dev 通道(SOMA 内部 soak)
./tools/promote.sh dev 0.X
# 自动 git push 到这个 repo,GitHub Pages 1-2 分钟 rebuild

# 3. soak ≥ 7 天没问题 → 推到 stable
./tools/promote.sh stable 0.X
# 30 分钟内所有客户机自动升级
```

## 紧急回滚

发现 stable 有严重 bug:

```bash
./tools/promote.sh stable 0.<上一版>
```

stable.txt 指回上一版本号。30 分钟内所有 stable 订阅的客户机用本机已缓存的旧镜像自动降级(不需要重新 pull)。

## URL

| 通道 | URL |
|---|---|
| dev | https://somarobotics.github.io/soda-ota-channels/dev.txt |
| stable | https://somarobotics.github.io/soda-ota-channels/stable.txt |

客户机 `update.sh` 默认 base URL:`https://somarobotics.github.io/soda-ota-channels`,可以通过 `CHANNEL_BASE` 环境变量覆盖。

## 备选托管方式

如果不想用 GitHub Pages(比如内网部署,客户机访问不了 github.io):

- **S3 + CloudFront**:把两个 `.txt` 文件传 S3 桶,CloudFront 暴露 HTTPS。改客户机的 `CHANNEL_BASE` 指向 CloudFront 域名。
- **自家 VPS + nginx / Caddy**:静态文件托管 + HTTPS。
- **Tailscale / 内网**:客户机都在 Tailscale 网络里就用 HTTP + 私有域名,免证书。

通道协议本身就一行版本号,任何能 serve 静态文本的 HTTPS 端点都行。
