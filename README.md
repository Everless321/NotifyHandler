# NotifyHandler

macOS 菜单栏应用，通过 Webhook 接收并显示系统通知。

## 功能

- 本地 HTTP 服务器接收 Webhook 请求
- macOS 原生系统通知
- 菜单栏常驻，后台运行
- 通知历史记录持久化
- 支持开机自启动

## 使用

### 启动服务

应用启动后自动在端口 `19527` 监听 HTTP 请求。可在设置中修改端口。

### API

#### 发送通知

```bash
curl -X POST http://localhost:19527/notify \
  -H "Content-Type: application/json" \
  -d '{
    "title": "标题",
    "body": "通知内容",
    "category": "info"
  }'
```

**请求参数**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| title | string | 是 | 通知标题 |
| body | string | 是 | 通知内容 |
| category | string | 否 | 类型：info/warning/error/success |
| timestamp | int64 | 否 | Unix 时间戳 |
| extra | object | 否 | 附加数据 |

#### 健康检查

```bash
curl http://localhost:19527/health
```

## 构建

```bash
xcodebuild -project notifyhandler.xcodeproj -scheme notifyhandler -configuration Release
```

## 系统要求

- macOS 14.0+
- 需授予通知权限

## 许可

MIT
