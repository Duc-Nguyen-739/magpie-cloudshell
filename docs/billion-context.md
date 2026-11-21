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

## Cài trên máy khác

Template: `config/billion-context.json`. Script: `scripts/setup-billion-context.sh`
(`--force` ghi đè config, `--start` bật proxy). Script cài package, plugin shim, copy
config, đặt `compaction.auto=false` và reload proxy. Credential `magpie` vẫn phải thêm
một lần qua web UI; repo không chứa key. Script **không** tạo group/model: tự tạo
`group/compress` (`routing=rotate`, `stays=off`) và thêm model trước khi nén.

## Cấu hình đang dùng (cập nhật 2026-11-21)

`compress` toàn cục: `nudgeGrowthTokens: 150000`, `preserveRecentTokens: 40000`,
`preserveRecentMessages: 10`, `preserveRecentTools: ["read"]`, `maxSummaryLength: 30000`.
`externalSummary`: bật, `concurrency: 8`, target `magpie/group/compress` →
`magpie/workbuddy-ai/hy4flash-free`, `targetTimeoutMs: 900000`,
`totalTimeoutMs: 1200000`, `maxSummaryBytes: 131072`. Provider `group/compress`:
`contextWindow: 262144`, `outputTokens: 32768`; `hy4flash-free`: `contextWindow: 960000`,
`outputTokens: 32768`.

Per-model (merge global → provider → model):

| Model | nudge | preserve tokens | msgs | max context | summary cap | ghi chú |
|---|---:|---:|---:|---:|---:|---|
| `group/leader` | 150k | 240k | 32 | 65% | 60k | task dài, giữ quyết định |
| `group/review` | 60k | 48k | 10 | 30% | 30k | `neverPreserveRecentTools: []`, `preserveRecentTools: ["bash"]` |
| `group/reviewplan` | 60k | 48k | 10 | 30% | 30k | như review |
| `group/coder` | 60k | 60k | 10 | 32% | 30k | |
| `group/tester` / `tester-2` / `tester-3` | 60k | 60k | 10 | 32% | 30k | |

Các entry model thật đi cùng group được hạ theo cùng tỉ lệ (xem bảng dưới). Ngày
21/11 hạ thêm một nấc (~20–25%) sau khi phiên build 1.4 MiB bị FreePi trả 413:
threshold thấp giúp nén trước khi body request vượt giới hạn của provider.

### Vì sao các con số này

- **Leader 240k/32/65%** — pipeline dài (brief → plan → code → 3 tester → audit) có
  nhiều báo cáo; 240k token gần nhất + 32 message giữ nguyên quyết định, gate và
  `R1..Rn`. `maxContextLimit: 65%` vẫn nén muộn hơn các session khác; nudge 150k để có nhiều
  thời gian fold trước khi request phình.
- **Review/reviewplan 48k/10/30%** — thường được Leader mở session mới cho từng việc,
  nên không cần giữ quá rộng; 30% đủ cho một lần khảo sát/plan/audit. `read` được bảo
  vệ trong recent zone (`neverPreserveRecentTools: []`, `preserveRecentTools: ["bash"]`),
  `bash` vẫn nén được để log dài không phình context.
- **Coder/tester 60k/10/32%** — coder cần plan + code đang sửa; tester cần log/test
  gần nhất. 32% là mức cân bằng sau khi hạ; thấp hơn nữa sẽ gặp PRESSURE NOTE (fold
  nhỏ liên tục, mất cache hit mà thu hồi ít).
- **`concurrency: 8`** — 0.1.216 pool nén process-wide, tối thiểu 4; 8 đủ cho 7 agent
  + target dự phòng. Range vượt slot xếp hàng, không fail.
- **`targetTimeoutMs: 900000` / `totalTimeoutMs: 1200000`** — fold 150k token có thể
  lâu; target 15 phút, batch 20 phút. Đây là **thời gian chờ xếp hàng**, không phải
  payload quá lớn. Nếu vẫn `target-timeout`, đưa model nhanh lên đầu `group/compress`
  hoặc tăng tiếp.
- **`maxSummaryLength` 60k Leader / 30k còn lại; `maxSummaryBytes: 131072`** — summary
  dài hơn cap bị từ chối nguyên khối; cap rộng để model viết đủ chi tiết. `outputTokens:
  32768` của model nén phải đủ lớn, nếu không summary bị cắt trước cap.

### Model thật vs group id

Bili chọn entry theo **model trong request**. Khi OpenCode/magpie trả về model thật
(`workbuddy-ai/deepseek-v4.1-flash-sg`, `freepi4/deepseek-v4.1-flash`, …), entry
`group/leader`/`group/review` không còn khớp. Vì vậy config có **cả hai**:
entry `group/*` cho lúc request còn là group, và entry model thật cho lúc session
chuyển sang member. Các entry thật đang có:

`workbuddy-ai/deepseek-v4.1-flash-sg`, `xingchi/gpt-6.1-sol`, `freepi4/...`,
`freepi/...`, `freepi6/...`, `freepi2/...`, `freepi3/...`, `freepi5/...`,
`autoclaw/zai_glm-5.3-flash`.

Nếu thêm group/model mới, thêm cả entry thật tương ứng; nếu không, session đó rơi về
global (50k preserve/12/30k) và dễ mất ngữ cảnh hơn dự kiến.

### Decision ledger

Plan phải có `## 14. Decision ledger` (decision_id, phase, scope, R, gate/expected,
status). Khi context bị nén, Leader yêu cầu `review`/`reviewplan` đọc lại ledger trong
plan; summary không còn là nguồn duy nhất cho quyết định.

## `group/compress` — target nén do người dùng tự tạo

Config trỏ `magpie/group/compress`. Repo **không** ghi ladder/model của group này; người
dùng tự tạo group (`routing=rotate`, `stays=off`) và tự thêm model. Chỉ cần group trả lời
được prompt tóm tắt; target dự phòng `magpie/workbuddy-ai/hy4flash-free` vẫn giữ.

Với `rotate`, lượt nén đi qua nhiều model/acc; nếu một model 429/5xx, group chuyển model
kế tiếp. Đo cũ (Particle-1, 2026-11-17): 6 request song song, p50 6–12 s; giữ để tham
chiếu, **chưa đo lại** ladder hiện tại.

### Khi external-summary lỗi

| Log | Sửa |
|---|---|
| `target-timeout` | tăng `budget.targetTimeoutMs` (đang 900s) hoặc đưa model nhanh lên đầu `group/compress` |
| `batch-deadline` | tăng `budget.totalTimeoutMs` (đang 1200s) hoặc giảm số range mỗi batch |
| `attempts=[t0:error]` | lỗi upstream (429/5xx/refusal); group/compress rotate model do bạn cấu hình, target dự phòng `hy4flash-free` |
| summary bị từ chối vì dài | tăng `compress.maxSummaryLength` (Leader 60k, còn lại 30k) hoặc giảm `summaryMaxChars` từng range |
| `maxSummaryBytes` | tăng (tối đa 1 MiB); hiện 131072 |

## Sau khi sửa config: phải reload

Server đọc config lúc khởi động. Sửa file xong phải reload: từ 0.1.216,
`POST /__bili/config/reload` nạp lại cả `compress` (`opts.compress = reloaded.compress`),
không chỉ routes/provider. Log xác nhận sau reload: `nudge idle ... interval=200000`.

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

Đã xác nhận end-to-end ngày **2026-11-20**: nén lại range 375 tin nhắn (~150k token)
qua `magpie/group/compress` → block `150k → 2,8k token` (summary 11.072 ký tự, dưới cap
60k), context session từ 33% xuống 16%. Trước đó 2026-11-19 đã nén range 55 tin nhắn
(~22.9k token), summary 12.221 ký tự. Nhớ đặt `max_tokens` ≥ 500 khi gọi thử trực tiếp:
model suy luận tiêu hết budget nhỏ vào reasoning token và trả `content` rỗng.

Giới hạn schema 0.1.216 (đọc từ code, không phải docs cũ): `totalTimeoutMs` và
`targetTimeoutMs` ≤ 2147483647; `maxSummaryBytes` 128–1048576; `concurrency` 1–32
(1–3 không thu nhỏ pool dưới 4).
