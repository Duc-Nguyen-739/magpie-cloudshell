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
    "nudgeGrowthTokens": 32000,
    "maxSummaryLength": 16000,
    "externalSummary": {
      "enabled": true,
      "concurrency": 1,
      "targets": [
        "magpie/group/free"
      ],
      "budget": {
        "totalTimeoutMs": 300000,
        "targetTimeoutMs": 180000,
        "maxSummaryBytes": 65536
      }
    }
  },
  "providers": {
    "magpie": {
      "api": "openai",
      "baseUrl": "http://127.0.0.1:3425/v1",
      "credentialRef": "magpie",
      "models": {
        "group/free": { "contextWindow": 200000, "outputTokens": 8192 }
      }
    }
  }
}
```

## `group/free` — chọn model nén (đo 2026-11-17)

Yêu cầu: chịu được **5–6 lượt nén cùng lúc**, nhanh, rẻ (free), và mỗi provider chỉ lấy
**một** model nhanh nhất; `workbuddy-ai/hy4flash-free` là chốt chặn cuối khi các provider
khác hết limit.

Cách đo: 6 request song song, non-stream, payload ~207k ký tự (≈45k token), `max_tokens 700`,
qua gateway `127.0.0.1:3425`. `p50` là trung vị của 6 request.

| Provider | Model nhanh nhất | 6 song song | p50 | Ghi chú |
|---|---|---|---|---|
| Cline | `cline/cline-free/solar-mini4` | 6/6 | **6,8 s** | không tốn reasoning token, ra 680 ch |
| Kilo | `kilo/baidu/ernie-5.5-flash-preview:free` | 6/6 | 7,2 s | 126 reasoning token |
| Kiro | `kiro/claude-haiku-4.5` | 6/6 | 7,7 s | 0 reasoning; Kiro Free chỉ 50 credit/tháng |
| OpenRouter | `openrouter/openrouter/free` (Free Models Router) | 429 khi burst | 2,1 s rồi 429 | trần **20 req/phút và 50 req/ngày** cho mọi model free |
| WorkBuddy | `workbuddy-ai/hy4flash-free` | 6/6 | 12,3 s | chốt chặn: 100M free token/ngày × 13 account |

Model bị loại vì không dùng được cho việc nén:

- `kilo/nvidia/nemotron-3-ultra-550b-a55b:free` — 0/6, treo tới hết 180 s.
- `kilo/nvidia/nemotron-3.5-lightning:free` — trả **0 ký tự** (toàn bộ token vào reasoning).
- `agy-cli/*` — 3/6, p50 ~40 s, `503 unfinished response`; quá chậm, đã bỏ khỏi đường nén.
- `freepi/deepseek-v4.1-flash` — 1/6, `429 one request at a time` (chỉ 1 request đồng thời).
- `cline/inclusionai/ling-3.2-flash:free`, `cline/thinkingmachines/inkling-2-small:free` — 404
  `model not supported`.
- `openrouter/google/gemma-4-31b-it:free` — 429 `free-models-per-min` ngay từ request đầu.
- `aihubmix/*-free` — tài khoản chưa nạp tiền nên mọi model free trả **200 kèm câu từ chối**
  (`Sorry, to prevent abuse of free resources, accounts that have not been recharged can only
  try 10 times`, `usage` = 0 token); model trả lời không phải bản tóm tắt, và
  `aihubmix/crouton-alpha-free` đã `404 model_retired`. Model trả phí thì
  `insufficient_user_quota`. Không dùng được cho tới khi nạp tiền.

Thứ tự `group/free` (routing `order`, mỗi provider một model, WorkBuddy cuối):

1. `cline/cline-free/solar-mini4`
2. `kilo/baidu/ernie-5.5-flash-preview:free`
3. `kiro/claude-haiku-4.5`
4. `openrouter/openrouter/free`
5. `workbuddy-ai/hy4flash-free`

OpenRouter đo nhanh nhất khi rảnh (4,0 s) nhưng **không thể ổn định bằng cách đổi model**:
`GET /api/v1/key` cho `is_free_tier: true`, `free_model_daily_requests {used:30, limit:50}`,
tức toàn bộ model free dùng chung **50 request/ngày** (và 20/phút), hai API key của cùng
tài khoản dùng chung đúng một bộ đếm. Đo lại 2026-11-17: `openrouter/openrouter/free` và
`openrouter/baidu/ernie-5.5-flash-preview:free` đều `429 free-models-per-min` ngay ở
request đơn. Vì vậy giữ **Free Models Router** (tự chọn model free còn sống, tốt hơn ghim
một model như `particle-1`) ở vị trí áp chót, và coi nó là vé số: 429 chỉ mất ~2 s rồi rơi
xuống WorkBuddy. Muốn bỏ hẳn OpenRouter thì dựng group 4 model, không mất gì vì WorkBuddy
đã là chốt chặn.

Đo lại cả group: **6/6, p50 6,7 s, 688 ký tự**, không có reasoning token.

**Vì sao budget như hiện tại (2026-11-17, sau khi bỏ chuỗi 5 model).** Chuỗi fallback cũ làm mỗi lần nén
hiện trong magpie là một model khác nhau: `hy4flash-free` hết `targetTimeoutMs`
→ `freepi/deepseek-v4.1-flash` trả 429 (`one request at a time`) → rơi tiếp sang
`agy-cli/gemini-2.5-flash-lite`, có lần chính target cuối cũng bị `499` sau 90 s.

Ba thay đổi, mỗi cái ứng với một lỗi đọc được trong `bili.log`:

1. **`concurrency: 1`** — đây là nguyên nhân chính của `target-timeout` sau khi đã cắt
   chuỗi. Một batch 3 range được bắn **song song** vào cùng một tài khoản WorkBuddy,
   cùng lúc với request chính của agent đang stream; log 02:27:54 ghi
   `499 after 1m59.963s` từ phía plugin, tức WorkBuddy vẫn đang xếp hàng chứ không trả
   lỗi. Gọi đơn lẻ cùng payload 49k token chỉ mất **12,6 s** (đo 2026-11-17), nên độ
   trễ là do tranh chấp, không phải kích thước. Serialize lại: 3 range × ~13 s vẫn thừa
   budget.
2. **`targetTimeoutMs` 180 s, `totalTimeoutMs` 300 s** — target đầu là model suy luận
   (`high`), khi tài khoản bận nó có thể giữ request rất lâu; 120 s chưa đủ.
3. **`maxSummaryLength` 16000** — plugin từ chối **nguyên khối** nếu bản tóm tắt dài hơn
   cap, và log cũ có `summary 13632/14155 chars exceeds cap 12000`. Nới cap là để model
   viết dư một chút vẫn qua. Lưu ý: cap hiệu lực là
   `min(summaryMaxChars của từng range, maxSummaryLength)`, nên nếu agent tự đặt
   `summaryMaxChars: 2500` cho một range thì nâng cap toàn cục **không** cứu được range
   đó — muốn cứu phải có target thứ hai chịu viết ngắn.

Target duy nhất là `magpie/group/free`: model đầu của group lo phần lớn, provider nào bị
limit thì `routing=order` tự rơi sang provider kế tiếp, và `workbuddy-ai/hy4flash-free`
đứng cuối làm chốt chặn (100M free token/ngày × 13 account nên gần như không cạn).

Đo trực tiếp qua gateway (`max_tokens: 4000`, non-stream, 346 KB ≈ 62k token đầu vào):
`hy4flash-free` **10,8 s**, `deepseek-v4.1-flash-sg` 7,6 s; gọi ngắn (50 token) có lúc
27 s khi tài khoản WorkBuddy đang bận. Vì vậy đừng hạ `targetTimeoutMs` xuống mức cũ
25–90 s: timeout ở đây là **xếp hàng**, không phải payload quá lớn.

`targets` là thứ tự thử: model đầu lỗi/timeout thì sang model sau. Đo latency thật với payload ~15k token (60k ký tự),
`max_tokens: 400`, non-stream:

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
