# OpenCode Zen — vì sao tắt `opencode-zen-free`, và vì sao `opencode-zen` chỉ còn `jev-1.13-free`

Tóm tắt: **kết cục** — `opencode-zen-free` (plugin, không cần key) **tắt hẳn** vì bể free
tính theo **IP dùng chung** đã cạn và không hồi lại. `opencode-zen` (API key) **bật** nhưng
**chỉ expose đúng `jev-1.13-free`**, dùng làm **classifier** cho `group/main`/`group/code`;
7 model free còn lại bị **429** ở upstream cho toàn bộ model free nên bỏ khỏi danh sách
expose. Ladder của `group/main`/`group/code` còn **6 rung** (WorkBuddy + AutoClaw), không
còn rung OpenCode nào. File này giữ lại làm **bản ghi bằng chứng** đo được, cùng cách kiểm
tra và cách bật lại nếu sau này muốn thử.

## 1. Chuyện gì xảy ra

Provider `opencode-zen` (thêm bằng `magpie provider add opencode-zen oc_…`) trả **429**
cho mọi model free. Triệu chứng người dùng thấy: gọi model free thì lỗi, chờ mãi mà
"không thấy reset quota" — vì hạn mức free theo API key **không có cửa sổ reset**, nó
dùng một lần rồi thôi.

Key không chết: nó vẫn trả lời cho model phân loại nội bộ `jev-1.13-free`. Chỉ nhóm
model free dùng cho chat bị 429. Vì vậy chuyện không phải "key hỏng" mà là "nhóm model
free gắn với client, không gắn với key".

## 2. Bằng chứng đo được

Đo ngày **29/10/2026**, máy này: magpie `0.1.1955`, OpenCode `2.2.0`, gateway
`127.0.0.1:3425`.

**Nhóm model free của `opencode-zen` — 429 cả 7 model** (mỗi dòng dưới đây là
`opencode-zen/<model>`):

| model | kết quả |
|---|---|
| `beam-free` | ✗ 429 |
| `flint-40b-free` | ✗ 429 |
| `mimo-v2.6-flash-free` | ✗ 429 |
| `nemotron-3.5-super-vl-free` | ✗ 429 |
| `nemotron-3.5-lightning-free` | ✗ 429 |
| `deepseek-v4.1-flash-free` | ✗ 429 |
| `glm-5.3-flash-free` | ✗ 429 |

Nguyên văn thông điệp upstream:

```
Free usage limit reached. Free models work in OpenCode (https://opencode.ai); subscribe to
OpenCode Go to keep going: https://opencode.ai/go
```

**Cùng key, model khác — vẫn sống:**

| model | kết quả |
|---|---|
| `opencode-zen/jev-1.13-free` | ✓ decide 768 ms |

**Provider plugin `opencode-zen-free` — chạy được:**

| model | kết quả |
|---|---|
| `opencode-zen-free/deepseek-v4.1-flash-free` | ✓ chat 1169 ms |
| `opencode-zen-free/glm-5.3-flash-free` | ✓ chat 2456 ms |
| `opencode-zen-free/nemotron-3.5-lightning-free` | ✓ chat 403 ms |
| `opencode-zen-free/flint-40b-free` | ✓ chat 863 ms |

Gọi qua gateway (`group/main`) cũng trả lời bình thường.

**Native OpenCode — cũng chạy, không cần đăng nhập:** `opencode run -m opencode/<model>`
trả lời với `deepseek-v4.1-flash-free`, `glm-5.3-flash-free`, `beam-free`;
`opencode auth list` chỉ có Kilo Gateway và DsHaness.

**Classifier hỏng không làm chết request:** group tạm đặt classifier 429 vẫn trả **200**
bình thường — chỉ mất tác dụng chọn mức reasoning.

## 3. Vì sao

Model free của Zen không phục vụ theo API key cá nhân. Client OpenCode và plugin này dùng
một credential công khai dùng chung, gửi kèm dấu vết client — mô tả của chính plugin gọi
nó là "the public credential".

Đây là **suy luận khớp với ba quan sát** đã đo, không phải cơ chế đọc được từ tài liệu
upstream:

- **(a)** key trần `opencode-zen` trả 429 cho cả 7 model free;
- **(b)** cùng model đó, cùng lúc, qua plugin `opencode-zen-free` thì chạy;
- **(c)** chính thông điệp 429 khuyên "Free models work in OpenCode".

Cộng lại: hạn mức free gắn với client chứ không gắn với key, và nó **không reset theo
thời gian**. Chờ là vô ích.

## 4. Vì sao `magpie quota` không hiện gì cho Zen

Zen không trả số dư qua API. `magpie quota` chỉ đọc được quota của provider có endpoint
trả số dư (AutoClaw, WorkBuddy, Kilo…); với Zen nó không có gì để đọc. Muốn xem credit
thì vào console <https://opencode.ai/console> bằng trình duyệt (Overview → Credits).

## 5. Cách sửa đã áp dụng

**Provider:**

| id | trạng thái | ghi chú |
|---|---|---|
| `opencode-zen-free` | **tắt** | provider expose 8 model free; plugin vẫn cài — bật lại được |
| `opencode-zen` | **bật** | chỉ expose `jev-1.13-free` (classifier); 40 model còn lại không picked |

Lần đầu chỉ tắt `opencode-zen` và chuyển hai rung OpenCode sang `opencode-zen-free`. Sau
khi bể free của plugin **cạn lần hai** và **không hồi lại sau hơn 40 phút** (hạn mức tính
theo IP dùng chung, không kiểm soát được), `opencode-zen-free` bị **tắt hẳn** ngày
**29/10/2026** và hai rung đó bị bỏ khỏi ladder.

`opencode-zen` thì khác: key vẫn sống cho model phân loại nội bộ `jev-1.13-free` (đo được
582–768 ms), nên provider được **bật lại** nhưng **thu hẹp danh sách expose còn đúng một
model** đó — `magpie provider models opencode-zen +jev-1.13-free`, rồi `-<model>` cho 8 model
còn lại. Vì `jev` không được offer cho agent, bật provider **không** làm bẩn ladder hay
danh sách model.

Tắt `opencode-zen-free` bằng `magpie provider off`, **không** `rm`: plugin còn đó, đổi ý thì
`magpie provider on opencode-zen-free` là xong. Muốn xoá hẳn key thì mới chạy
`magpie provider rm opencode-zen` (không hoàn lại được).

**`group/main` và `group/code` — 6 rung, thứ tự = thứ tự fallback:**

```
1 workbuddy-ai/deepseek-v4.1-flash
2 workbuddy-ai/deepseek-v4.1-flash-sg
3 autoclaw/zaicoding_glm-5.3
4 autoclaw/zai_glm-5.3-flash
5 workbuddy-ai/glm-5.3
6 workbuddy-ai/glm-5.3-flash
```

**`group/glm` — 6 model:**

```
autoclaw/zaicoding_glm-5.3, autoclaw/zai_glm-5.3-flash, autoclaw/zai_auto-fast,
autoclaw/zai_auto, workbuddy-ai/glm-5.3, workbuddy-ai/glm-5.3-flash
```

**`group/deepseek` — 2 model:**

```
workbuddy-ai/deepseek-v4.1-flash, workbuddy-ai/deepseek-v4.1-flash-sg
```

**Classifier** của `group/main` và `group/code`: `opencode-zen/jev-1.13-free` — model phân
loại nội bộ của Zen, **không** bị chặn free tier (đo 582–768 ms mỗi lượt), không hiện cho
agent chọn, và **không** đụng bể IP dùng chung của `opencode-zen-free` (vì sao, xem mục 6).

**Vì sao trước đây hai model OpenCode nằm cuối:** chúng là đường miễn phí, phụ thuộc
plugin cộng đồng — chỉ nên dùng khi các rung chính (WorkBuddy, AutoClaw) đã hỏng hoặc hết
quota, nên không được đặt lên trên. Khi bể IP cạn hẳn thì cả lý do lẫn giá trị dự phòng
không còn, nên hai rung đó bị bỏ.

Hai file nguồn: `scripts/setup-settings.sh` (tắt provider) và
`scripts/setup-groups.sh` (ladder + classifier). `bash scripts/finish.sh` gọi cả hai.

## 6. Vì sao classifier không nằm trên đường Zen Free

Classifier chạy **mỗi lượt** (`effort=auto`), nên nó không được phép phụ thuộc vào bể IP
dùng chung của `opencode-zen-free`: bể cạn là mọi lượt đều cõng thời gian chờ.

`jev-1.13-free` **không** nằm trên đường free đó: nó là model phân loại nội bộ, gọi qua
**API key** của `opencode-zen`, và **không** thuộc nhóm model free bị 429. Đo trên máy này
ngày 29/10/2026 (magpie `0.1.1955`): `✓ decide 582 ms` (một lần đo khác 768 ms), trong khi
7 model free cùng key đều 429. Vì vậy classifier dùng được `jev` mà không đụng bể IP.

Số đo lịch sử, để thấy vì sao **không** dùng đường free:

- **Bể Zen Free cạn sau ~20 request** trong bài test. Khi cạn, log ghi **3 lần** classifier
  không trả lời (2 timeout 8 s, 1 trả chuỗi rỗng) trong khoảng 20 phút, và mỗi lượt chậm
  thêm tới **8 s**.
- **`workbuddy-ai/hy3` (classifier cũ):** 10 request mà `magpie accounts` trước/sau đều
  `used = 12.665714` → **không tốn credit**; 4/4 lượt classifier trả lời (1,06–1,55 s,
  thường 1,1–1,2 s), **0 dòng** lỗi classifier trong log.

**Nếu `jev` bị Zen gỡ hoặc bắt đầu tính tiền:** đổi classifier về `workbuddy-ai/hy3` —
model này đã đo là chạy tốt, không tốn credit:

```sh
magpie group set main classifier=workbuddy-ai/hy3
magpie group set code classifier=workbuddy-ai/hy3
```

và sửa `CLASSIFIER=` trong `scripts/setup-groups.sh` cho khớp. Phương án hai:
`kilo/reflection/beam-free` — 10/10 request tuần tự 200 (0,80–0,94 s), 8 request đồng thời
đều 200, 4/4 lượt classifier OK, 0 lỗi; đánh đổi là thêm provider Kilo vào đường bắt buộc
của mọi lượt.

## 7. Kiểm tra lại

```sh
export PATH="$HOME/.local/bin:$PATH"

magpie providers | grep -i zen
# opencode-zen       ●  (bật, 1 of 41 models)
# opencode-zen-free  ○  (tắt)

magpie provider models opencode-zen | grep 'opencode-zen/'
# đúng 1 dòng: opencode-zen/jev-1.13-free

magpie models | grep -E '^[[:space:]]+opencode-zen/'
# phải rỗng (jev không offer cho agent). Lưu ý `magpie models` có in dòng gợi ý
# "magpie provider models opencode-zen +<model> exposes one" — đó không phải model.

magpie group main
# 6 rung đúng thứ tự mục 5, dòng cuối: workbuddy-ai/glm-5.3-flash
# dòng classifier:
#   opencode-zen/jev-1.13-free
#   effort  auto

magpie group glm           # 6 model
magpie group deepseek      # 2 model
# không còn model opencode-zen nào trong group

curl -s -m 90 http://127.0.0.1:3425/v1/chat/completions \
  -H 'Authorization: Bearer magpie' -H 'Content-Type: application/json' \
  -d '{"model":"group/main","messages":[{"role":"user","content":"Say OK"}],"max_tokens":64}'
# HTTP 200, choices[0].message.content = "OK"
```

Lưu ý khi tự đo: model trong ladder là model reasoning, `max_tokens` quá nhỏ (ví dụ 10)
thì toàn bộ token bị tiêu vào `reasoning_content` và `content` trả về `null` — request
vẫn 200. Dùng `max_tokens` ≥ 64 để thấy nội dung.

## 8. Đường khác: OpenCode trực tiếp

Provider `opencode` của chính OpenCode cũng chạy được các model `opencode/*` **mà không
cần đăng nhập**. Trong OpenChamber, chọn thẳng model:

```
opencode/deepseek-v4.1-flash-free
```

Trên máy này, 9 model `opencode/*` đã được bỏ ẩn trong picker của OpenChamber.

Đây là đường **không qua magpie**: không có ladder, không có fallback, không có
`effort=auto`, không chia sẻ với Claude Code hay agent khác. Chỉ dùng khi muốn một model
free nhanh trong UI, không phải để thay `group/main`.

## 9. Rủi ro

- **Plugin cộng đồng.** `opencode-zen-free` là plugin (`opencode-zen-freex`), không chính
  thức. Hiện provider đang tắt nên ladder không phụ thuộc nó; nếu bật lại để thử thì
  `magpie plugin update` lên bản hỏng sẽ làm rung OpenCode chết. Cách xử:
  ghim lại bản đang chạy: `magpie plugin add opencode-zen-freex@0.5.16`, rồi
  `magpie-headless-stop && magpie-headless-start`.
- **Free tier có giới hạn riêng, tính theo IP dùng chung.** Zen có thể siết thêm bất cứ
  lúc nào — đó chính là lý do `opencode-zen-free` đã bị tắt thay vì giữ làm rung cuối.
- **`jev-1.13-free` là model nội bộ của Zen:** nó có thể bị gỡ hoặc bị tính tiền bất cứ
  lúc nào. Khi đó classifier đặt được nhưng gọi lỗi → log `couldn't say`, request vẫn 200.
  Cách xử: đổi classifier về `workbuddy-ai/hy3` (mục 6).
- **Classifier lỗi giữa phiên.** Request vẫn 200 (đã đo), chỉ mất tác dụng chọn mức
  reasoning; agent tự dùng mức mặc định.
- **`magpie quota` im lặng với Zen** — không phải lỗi, xem mục 4.

## 10. Hoàn tác / bật lại

Trạng thái hiện tại: `opencode-zen-free` **tắt**, `opencode-zen` **bật với đúng
`jev-1.13-free`**. Muốn thử lại đường plugin:

```sh
magpie provider on opencode-zen-free     # plugin vẫn cài, chỉ cần bật provider
git revert <commit> && bash scripts/finish.sh
```

`git revert` trả `scripts/setup-groups.sh` và `scripts/setup-settings.sh` về trạng thái
trước (classifier `workbuddy-ai/hy3`, `opencode-zen` tắt); ladder vẫn **6 rung** vì vòng
trước đã bỏ hai rung OpenCode. `finish.sh` áp lại lên máy. Nếu không muốn revert, thêm tay
hai model vào group:

```sh
magpie group set main models+=opencode-zen-free/deepseek-v4.1-flash-free,opencode-zen-free/glm-5.3-flash-free
magpie group set code models+=opencode-zen-free/deepseek-v4.1-flash-free,opencode-zen-free/glm-5.3-flash-free
```

Nhớ rằng hạn mức tính theo IP dùng chung: bể cạn thì bật lại cũng không giúp gì.

Muốn **trả classifier về WorkBuddy** (khi `jev` bị Zen gỡ): xem lệnh ở mục 6, rồi sửa
`CLASSIFIER=` trong `scripts/setup-groups.sh` cho khớp.

Muốn **tắt hẳn** `opencode-zen` (không dùng `jev` nữa): `magpie provider off opencode-zen`
và sửa khối provider trong `scripts/setup-settings.sh` cho khớp.

## 11. Đo lại sau này

So hai provider bằng cùng một model, cùng một lúc (`opencode-zen` đang bật,
`opencode-zen-free` đang tắt — bật lại nếu muốn đo nó):

```sh
magpie provider test opencode-zen      deepseek-v4.1-flash-free
magpie provider test opencode-zen      jev-1.13-free
magpie provider test opencode-zen-free deepseek-v4.1-flash-free
magpie provider test opencode-zen-free glm-5.3-flash-free
```

Kỳ vọng hiện tại: hai dòng `opencode-zen` free → ✗ 429, `jev-1.13-free` → ✓ decide,
hai dòng `opencode-zen-free` → ✓ chat (nếu đã bật provider). Nếu `opencode-zen` free bắt
đầu trả lời lại thì Zen đã mở lại free tier cho API key — lúc đó có thể cân nhắc đưa về
ladder.
