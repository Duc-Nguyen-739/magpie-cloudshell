# billion-context — nén hội thoại của OpenCode

`billion-context` **không phải** một phần của magpie: nó là plugin của OpenCode, thay cho
cơ chế compaction gốc. Repo này ghi lại cấu hình đang chạy và lỗi đã gặp để lần sau không
phải chẩn đoán lại.

## Nó nằm ở đâu

| | |
|---|---|
| Plugin OpenCode | `~/.config/opencode/plugins/billion-context/index.js` — chỉ re-export gói npm |
| Gói npm | `~/.local/lib/node_modules/billion-context` (bản đang chạy: **0.1.215**) |
| Config | `~/.config/billion-context/billion-context.json` |
| Credential | `~/.config/billion-context/billion-context.json.summary-credentials.json` (key `magpie`) |
| Server | `node …/dist/index.js start --host 127.0.0.1 --port 18787` (lane `opencode`) |
| State / log | `~/.local/state/billion-context/` — `bili.log`, `port-zone.json` |

`opencode.json` đặt `"compaction": {"auto": false}` là **có chủ đích**: billion-context tự
quyết định khi nào nén. Đừng bật lại compaction gốc, hai bên sẽ giành nhau.

## Lỗi đã gặp (2026-11-16)

OpenCode hiện liên tục:

```
[COMPRESSION FAILED: all configured external summary candidates failed or exceeded
their budget. Nothing compressed; do not retry unchanged configuration — summaries
longer than the configured cap are rejected whole, so raise compress.maxSummaryLength
or request less via per-range summaryMaxChars.]
[batch=deadline result=failed reason=exhausted attempts=[t0:error,t1:error]]
```

`bili.log` cho thấy nguyên nhân thật **không phải** `maxSummaryLength`:

```
[external-summary] candidate group/main attempt 1/3 failed before response
(target-timeout; elapsed=25013ms, budget target=25000ms total=50000ms,
protocol=openai, stream=false, payload≈417915B, input≈96970tok, outCap=20000ch):
This operation was aborted
```

Budget mặc định là **25 s cho một target, 50 s cho cả batch**. Payload nén của một phiên
dài (60k–500k ký tự) không kịp trả lời trong 25 s, nên request bị huỷ; target thứ hai cũng
hết giờ batch. Gateway vẫn khoẻ — `headless.log` chỉ ghi `499 after 24.975s: the agent
canceled the request`, tức **phía gọi tự huỷ**, không phải magpie treo.

## Cấu hình đang dùng

```json
{
  "compress": {
    "maxSummaryLength": 12000,
    "nudgeGrowthTokens": 32000
  },
  "externalSummary": {
    "enabled": true,
    "targets": [
      "magpie/workbuddy-ai/deepseek-v4.1-flash-sg",
      "magpie/group/main",
      "magpie/workbuddy-ai/hy4flash-free"
    ],
    "budget": {
      "totalTimeoutMs": 240000,
      "targetTimeoutMs": 90000,
      "maxSummaryBytes": 65536
    }
  },
  "providers": {
    "magpie": {
      "api": "openai",
      "baseUrl": "http://127.0.0.1:3425/v1",
      "credentialRef": "magpie",
      "models": {
        "group/main": { "contextWindow": 1000000, "outputTokens": 8192 },
        "workbuddy-ai/hy4flash-free": { "contextWindow": 960000, "outputTokens": 8192 },
        "workbuddy-ai/deepseek-v4.1-flash-sg": { "contextWindow": 1000000, "outputTokens": 8192 }
      }
    }
  }
}
```

`targets` là thứ tự thử: model đầu lỗi/timeout thì sang model sau. Đo latency thật với
payload ~15k token (60k ký tự), `max_tokens: 400`, non-stream:

| Model | Thời gian |
|---|---|
| `workbuddy-ai/deepseek-v4.1-flash-sg` | **1,96 s** |
| `workbuddy-ai/glm-5.3-flash` | 3,44 s |
| `freepi/deepseek-v4.1-flash` | 4,25 s |
| `group/main` | 5,22 s |
| `workbuddy-ai/hy4flash-free` | 5,90 s |
| `agy-cli/gemini-3.8-flash` | 15,27 s |
| `autoclaw/zai_glm-5.3-flash` | 63,84 s |

Đừng đưa AutoClaw vào `targets`: 64 s một request thì mọi batch đều hết giờ. Cũng đừng để
`group/main` làm target duy nhất — nó có thể rơi xuống đúng model chậm đó.

## Sau khi sửa config: phải reload

Server đọc `externalSummary` lúc khởi động. Sửa file xong mà không reload thì lần nén kế
tiếp vẫn dùng budget cũ (đây chính là lý do lần sửa đầu "không có tác dụng").

```sh
curl -sS -X POST http://127.0.0.1:18787/__bili/config/reload
# {"ok":true,"count":1,"routes":["magpie"]}
```

Không cần kill server: nó đang proxy toàn bộ request model của phiên OpenCode, kill sẽ làm
đứt phiên. Reload chỉ thay routes + provider trong bộ nhớ.

Kiểm tra lần nén kế tiếp:

```sh
tail -5 ~/.local/state/billion-context/bili.log | grep external-summary
# completed 3/3 range(s); batch=finished result=success attempts=[t0:success]
```

## Chọn tham số nào khi vẫn lỗi

| Log nói | Sửa |
|---|---|
| `target-timeout` | tăng `budget.targetTimeoutMs`, hoặc đưa model nhanh lên đầu `targets` |
| `batch-deadline` | tăng `budget.totalTimeoutMs`, hoặc giảm số range mỗi batch |
| summary bị từ chối vì dài | tăng `compress.maxSummaryLength`, hoặc giảm `summaryMaxChars` từng range |
| `maxSummaryBytes` | tăng lên (tối đa 1 MiB) nếu summary hợp lệ vẫn bị cắt |

Giới hạn schema: `totalTimeoutMs` 100–600000, `targetTimeoutMs` 100–`totalTimeoutMs`,
`maxSummaryBytes` 128–1048576, `concurrency` 1–32.
