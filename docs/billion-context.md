# billion-context — nén hội thoại của OpenCode

`billion-context` **không phải** một phần của magpie: nó là plugin của OpenCode, thay cho
cơ chế compaction gốc. Repo này ghi lại cấu hình đang chạy và lỗi đã gặp để lần sau không
phải chẩn đoán lại.

## Nó nằm ở đâu

| | |
|---|---|
| Plugin OpenCode | `~/.config/opencode/plugins/billion-context/index.js` — chỉ re-export gói npm |
| Gói npm | `~/.local/lib/node_modules/billion-context` (bản đang chạy: **0.1.216**) |
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
    "nudgeGrowthTokens": 100000,
    "preserveRecentMessages": 8,
    "preserveRecentTokens": 30000,
    "preserveRecentTools": ["read"],
    "maxSummaryLength": 16000,
    "externalSummary": {
      "enabled": true,
      "concurrency": 6,
      "targets": [
        "magpie/group/free",
        "magpie/workbuddy-ai/hy4flash-free"
      ],
      "budget": {
        "totalTimeoutMs": 480000,
        "targetTimeoutMs": 240000,
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
        "group/free": { "contextWindow": 200000, "outputTokens": 8192 },
        "workbuddy-ai/hy4flash-free": { "contextWindow": 960000, "outputTokens": 8192 }
      }
    }
  }
}
```

## Cấu hình cho 7 agent (2026-11-19)

Bảy agent (leader, review, reviewplan, coder, tester, tester-2, tester-3) dùng chung một
instance bili, nên `compress.*` là toàn cục. Mục tiêu: agent suy luận liền mạch, không bị
nén cắt ngang giữa việc.

- **`nudgeGrowthTokens: 100000`** — nén chỉ chạy khi có đủ 100k token khối nén được
  **và** đã tăng thêm ít nhất 45k token kể từ mốc trước. Các model đang hoạt động có cửa
  sổ hiệu dụng ~800k–1M (bili trừ headroom: 1M → 872k–917k), nên 100k chỉ là ~12%.
  Phiên review trước đây nén 3 lần trong 60 request với mốc 30k; mốc 100k đẩy lần nén
  đầu lên ~150–200k (system prompt 20–68k + 30k giữ lại + 100k khối nén), đủ để phần
  lớn việc của subagent kết thúc mà không nén.
- **`preserveRecentTokens: 30000`** + **`preserveRecentMessages: 8`** — giữ nguyên văn
  30k token gần nhất và 8 tin nhắn gần nhất; phần đang suy luận không bị gộp.
- **`preserveRecentTools: ["read"]`** — bỏ `read` khỏi danh sách "không bao giờ giữ"
  mặc định, nên file vừa đọc vẫn nằm trong vùng bảo vệ thay vì bị nén ngay
  (đúng khuyến nghị #1198/#1277 của bili cho workflow đọc nhiều file). `bash` vẫn
  compressible để log dài không phình context.
- **`concurrency: 6`** — trong 0.1.216 pool nén là process-wide và **không nhỏ hơn 4**:
  đặt 1–3 chỉ là danh nghĩa, `effectiveConcurrency()` vẫn trả 4. Đặt 6 để đủ 6 range
  nén song song; đã đo 6 request đồng thời với payload ~45k token:
  `workbuddy-ai/hy4flash-free` 6/6 trong 19 s, `group/free` 6/6 trong 31 s. Nếu 7 agent
  cùng nén một lúc, range thứ 7 chỉ **xếp hàng** chờ slot, không fail.
- **`maxSummaryLength: 16000`** — giữ cap cũ; summary dài hơn bị từ chối nguyên khối.
  Nếu sau này thấy summary mất chi tiết, nâng lên 24000 (vẫn dưới `outputTokens: 8192`
  của target, ~6k token).
- **`targetTimeoutMs: 240000` / `totalTimeoutMs: 480000`** — fold 100k lớn gấp ~3–4 lần
  fold 22.9k trước đây, nên nới target lên 240 s và batch lên 480 s; nếu target đầu lỗi,
  target dự phòng vẫn còn 240 s. Đừng để 25–30 s như mặc định cũ — đó là mức đã làm
  `target-timeout` ở lần nén 97k token.

Nén không bao giờ cắt một lượt đang stream: bili chỉ chèn nudge **giữa các lượt**, rồi
gộp các range cũ. Vì vậy "không bị cắt ngang" ở đây nghĩa là giữ vùng làm việc gần
nguyên vẹn và giảm số lần gộp, không phải tắt nén.

### Khi `external-summary` báo `attempts=[t0:error]`

Đây là lỗi từ upstream (429/5xx/refusal), **không phải** `target-timeout`. Log 0.1.216
chỉ ghi `t0:error` mà không kèm chi tiết, nên đừng xử lý bằng cách tăng giây. Cách xử lý:

1. Thêm target dự phòng (đã làm): `magpie/workbuddy-ai/hy4flash-free` sau `group/free`.
   Range lỗi được thử lại trên WorkBuddy; range không nén được vẫn nằm trong
   `compressibleRanges` và sẽ được thử lại ở nudge sau, không mất dữ liệu.
2. Nếu cả hai target đều lỗi, gọi trực tiếp model nghi vấn với cùng payload để lấy
   status thật (đừng tăng timeout: timeout có outcome `timeout` và log `target-timeout`).
3. Lỗi 1/2 range trong một batch thường là tranh chấp/rate limit khi hai range nén song
   song; target dự phòng là cách chữa, không phải tăng `concurrency` (pool đã tối thiểu 4).

## `group/free` — chọn model nén (đo 2026-11-17)

> **Ladder thực tế trên máy này (2026-11-19)**: `kilo/particle-ai/particle-1:free` →
> `openrouter/particle-ai/particle-1:free` →
> `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` → `workbuddy-ai/hy4flash-free`,
> `routing=rotate`, `stays=off`. Cline và Groq không có provider trên máy nên
> `setup-groups.sh` bỏ qua; WorkBuddy là bậc cuối. Bảng đo dưới đây là của ladder cũ,
> giữ để tham chiếu — **chưa đo lại** ladder mới.

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

Thứ tự `group/free` thực tế trên máy này (routing `rotate`, mỗi provider một model):

1. `kilo/particle-ai/particle-1:free`
2. `openrouter/particle-ai/particle-1:free`
3. `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` — dự phòng
4. `workbuddy-ai/hy4flash-free` — bậc cuối

Ladder cũ (đo trong bảng trên) là `cline/cline-free/solar-mini4` →
`kilo/baidu/ernie-5.5-flash-preview:free` → `kiro/claude-haiku-4.5` →
`openrouter/openrouter/free` → `workbuddy-ai/hy4flash-free` (routing `order`).

OpenRouter đo nhanh nhất khi rảnh (4,0 s) nhưng **không thể ổn định bằng cách đổi model**:
`GET /api/v1/key` cho `is_free_tier: true`, `free_model_daily_requests {used:30, limit:50}`,
tức toàn bộ model free dùng chung **50 request/ngày** (và 20/phút), hai API key của cùng
tài khoản dùng chung đúng một bộ đếm. Đo lại 2026-11-17: `openrouter/openrouter/free` và
`openrouter/baidu/ernie-5.5-flash-preview:free` đều `429 free-models-per-min` ngay ở
request đơn. Vì vậy giữ **Free Models Router** (tự chọn model free còn sống, tốt hơn ghim
một model như `particle-1`) ở vị trí áp chót — đó là lý do của ladder cũ. Ladder thực tế
trên máy này ghim thẳng `openrouter/particle-ai/particle-1:free` và dùng `routing=rotate`,
nên lượt nén chỉ chạm OpenRouter khoảng 1/3 số lần; WorkBuddy là bậc cuối. NVIDIA thêm
2026-11-19 làm dự phòng khi các provider Particle-1 hết quota, thay vì rơi thẳng vào
`target-timeout`.

Đo cả group cũ: **6/6, p50 6,7 s, 688 ký tự**, không có reasoning token. Chưa đo lại
ladder particle-1.

**Vì sao budget như hiện tại (2026-11-17, sau khi bỏ chuỗi 5 model).** Chuỗi fallback cũ làm mỗi lần nén
hiện trong magpie là một model khác nhau: `hy4flash-free` hết `targetTimeoutMs`
→ `freepi/deepseek-v4.1-flash` trả 429 (`one request at a time`) → rơi tiếp sang
`agy-cli/gemini-2.5-flash-lite`, có lần chính target cuối cũng bị `499` sau 90 s.

Ba thay đổi, mỗi cái ứng với một lỗi đọc được trong `bili.log`:

1. **`concurrency`** — một batch 3 range từng bắn **song song** vào cùng một tài khoản
   WorkBuddy, cùng lúc với request chính của agent đang stream; log 02:27:54 ghi
   `499 after 1m59.963s` từ phía plugin, tức WorkBuddy xếp hàng chứ không trả lỗi. Gọi
   đơn lẻ cùng payload 49k token chỉ mất **12,6 s** (đo 2026-11-17), nên độ trễ là do
   tranh chấp, không phải kích thước. Trong 0.1.216 pool process-wide luôn tối thiểu 4;
   đặt `concurrency: 1` **không** serialize. Nay đặt 6 (đã đo 6 request song song trên cả
   hai target, tất cả trả trong ~9–10 s); range thứ 7 xếp hàng chờ slot, không fail.
2. **`targetTimeoutMs` 240 s, `totalTimeoutMs` 480 s** — target đầu là model suy luận
   (`high`), khi tài khoản bận nó có thể giữ request rất lâu; 120 s chưa đủ, và fold
   100k cần nhiều thời gian hơn fold 30k. Batch 480 s để target dự phòng còn 240 s.
3. **`maxSummaryLength` 16000** — plugin từ chối **nguyên khối** nếu bản tóm tắt dài hơn
   cap, và log cũ có `summary 13632/14155 chars exceeds cap 12000`. Nới cap là để model
   viết dư một chút vẫn qua. Lưu ý: cap hiệu lực là
   `min(summaryMaxChars của từng range, maxSummaryLength)`, nên nếu agent tự đặt
   `summaryMaxChars: 2500` cho một range thì nâng cap toàn cục **không** cứu được range
   đó — muốn cứu phải có target thứ hai chịu viết ngắn.

Target thứ nhất là `magpie/group/free`; target thứ hai là
`magpie/workbuddy-ai/hy4flash-free` (thêm 2026-11-19) để range lỗi được thử lại trên
WorkBuddy thay vì hỏng cả batch. Với `routing=rotate`, mỗi lượt nén đi một provider khác
nhau; nếu cả hai target cùng bị limit thì range vẫn nằm trong `compressibleRanges` và
được thử lại ở nudge sau.

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

Server đọc config lúc khởi động. Sửa file xong phải reload: từ 0.1.216,
`POST /__bili/config/reload` nạp lại cả `compress` (`opts.compress = reloaded.compress`),
không chỉ routes/provider. Log xác nhận sau reload: `nudge idle ... interval=100000`.

```sh
curl -sS -X POST http://127.0.0.1:18787/__bili/config/reload
# {"ok":true,"count":1,"routes":["magpie"]}
```

Không cần kill server: nó đang proxy toàn bộ request model của phiên OpenCode, kill sẽ làm
đứt phiên. Reload thay routes, provider và `compress` trong bộ nhớ.

Kiểm tra lần nén kế tiếp:

```sh
tail -5 ~/.local/state/billion-context/bili.log | grep external-summary
# completed 3/3 range(s); batch=finished result=success attempts=[t0:success]
```

Đã xác nhận end-to-end ngày **2026-11-19**: nén thật một range 55 tin nhắn (~22.9k token)
qua `magpie/group/free` → `completed 1/1 range(s); attempts=[t0:success]`, summary
12.221 ký tự (dưới cap 16.000), tiết kiệm ~36k token. Bốn model trong ladder đều trả lời
được khi gọi riêng; nhớ đặt `max_tokens` ≥ 500 vì model suy luận tiêu hết budget nhỏ
vào reasoning token và trả `content` rỗng.

## Chọn tham số nào khi vẫn lỗi

| Log nói | Sửa |
|---|---|
| `attempts=[t0:error]` | lỗi upstream (429/5xx/refusal), không phải timeout; thêm target dự phòng như `magpie/workbuddy-ai/hy4flash-free` — xem mục trên |
| `target-timeout` | tăng `budget.targetTimeoutMs`, hoặc đưa model nhanh lên đầu `targets` |
| `batch-deadline` | tăng `budget.totalTimeoutMs`, hoặc giảm số range mỗi batch |
| summary bị từ chối vì dài | tăng `compress.maxSummaryLength`, hoặc giảm `summaryMaxChars` từng range |
| `maxSummaryBytes` | tăng lên (tối đa 1 MiB) nếu summary hợp lệ vẫn bị cắt |

Giới hạn schema: `totalTimeoutMs` 100–600000, `targetTimeoutMs` 100–`totalTimeoutMs`,
`maxSummaryBytes` 128–1048576, `concurrency` 1–32 (1–3 không thu nhỏ pool dưới 4).
