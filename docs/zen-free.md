# OpenCode Zen Free — vì sao ladder bỏ provider `opencode-zen`

Tóm tắt: đường **API key** của OpenCode Zen (`opencode-zen`) đã bị chặn ở upstream cho
toàn bộ model free. Repo chuyển hai rung OpenCode của ladder sang provider
**`opencode-zen-free`** (plugin, không cần key) và đẩy chúng xuống **cuối** ladder. File
này ghi lại bằng chứng đo được, cách sửa đã áp dụng, cách kiểm tra và cách hoàn tác.

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
| `opencode-zen-free` | **bật** | 8 model, dùng cho 2 rung cuối của ladder |
| `opencode-zen` | **tắt** | key giữ nguyên, không expose model nào |

Tắt bằng `magpie provider off`, **không** `rm`: key còn đó, đổi ý thì
`magpie provider on opencode-zen` là xong. Muốn xoá hẳn thì mới chạy
`magpie provider rm opencode-zen` (không hoàn lại được).

**`group/main` và `group/code` — 8 rung, thứ tự = thứ tự fallback:**

```
1 workbuddy-ai/deepseek-v4.1-flash
2 workbuddy-ai/deepseek-v4.1-flash-sg
3 autoclaw/zaicoding_glm-5.3
4 autoclaw/zai_glm-5.3-flash
5 workbuddy-ai/glm-5.3
6 workbuddy-ai/glm-5.3-flash
7 opencode-zen-free/deepseek-v4.1-flash-free
8 opencode-zen-free/glm-5.3-flash-free
```

**`group/glm`:**

```
autoclaw/zaicoding_glm-5.3, autoclaw/zai_glm-5.3-flash, autoclaw/zai_auto-fast,
autoclaw/zai_auto, workbuddy-ai/glm-5.3, workbuddy-ai/glm-5.3-flash,
opencode-zen-free/glm-5.3-flash-free
```

**`group/deepseek`:**

```
workbuddy-ai/deepseek-v4.1-flash, workbuddy-ai/deepseek-v4.1-flash-sg,
opencode-zen-free/deepseek-v4.1-flash-free
```

**Classifier** của `group/main` và `group/code`: `workbuddy-ai/hy3` — free, không tốn
credit WorkBuddy, trả lời 1,1–1,2 s mỗi lượt, và không đụng bể IP dùng chung của Zen Free
(classifier cũ `opencode-zen/jev-1.13-free` thuộc provider vừa tắt; vì sao classifier
không nằm trên bể Zen Free, xem mục 6).

**Vì sao hai model OpenCode nằm cuối:** đây là đường miễn phí, phụ thuộc plugin cộng
đồng — chỉ nên dùng khi các rung chính (WorkBuddy, AutoClaw) đã hỏng hoặc hết quota.
Đặt lên trên sẽ khiến mọi lượt đi qua đường kém ổn định nhất.

Hai file nguồn: `scripts/setup-settings.sh` (bật/tắt provider) và
`scripts/setup-groups.sh` (ladder + classifier). `bash scripts/finish.sh` gọi cả hai.

## 6. Vì sao classifier không nằm trên Zen Free

Classifier chạy **mỗi lượt** (`effort=auto`), nên nó không được phép phụ thuộc vào bể IP
dùng chung của Zen Free: bể cạn là mọi lượt đều cõng thời gian chờ.

Số đo trên máy này, ngày 29/10/2026 (magpie `0.1.1955`):

- **Bể Zen Free cạn sau ~20 request** trong bài test. Khi cạn, log ghi **3 lần** classifier
  không trả lời (2 timeout 8 s, 1 trả chuỗi rỗng) trong khoảng 20 phút, và mỗi lượt chậm
  thêm tới **8 s**.
- **`workbuddy-ai/hy3` thay vào:** 10 request mà `magpie accounts` trước/sau đều
  `used = 12.665714` → **không tốn credit**; 4/4 lượt classifier trả lời (1,06–1,55 s,
  thường 1,1–1,2 s), **0 dòng** lỗi classifier trong log. Hy3 nằm trên WorkBuddy — provider
  đã là rung 1–2 của ladder, nên không thêm phụ thuộc mới.

**Phương án dự phòng nếu WorkBuddy hỏng:** `kilo/reflection/beam-free` — 10/10 request
tuần tự 200 (0,80–0,94 s), 8 request đồng thời đều 200, 4/4 lượt classifier OK, 0 lỗi.
Đổi bằng:

```sh
magpie group set main classifier=kilo/reflection/beam-free
magpie group set code classifier=kilo/reflection/beam-free
```

và sửa `CLASSIFIER=` trong `scripts/setup-groups.sh` cho khớp. Đánh đổi: thêm provider Kilo
vào đường bắt buộc của mọi lượt, trong khi Kilo chưa có vai trò nào khác trong pipeline.

## 7. Kiểm tra lại

```sh
export PATH="$HOME/.local/bin:$PATH"

magpie providers | grep -i zen
# opencode-zen-free  ●  (bật)
# opencode-zen       ○  (tắt)

magpie models | grep '^opencode-zen/'
# phải rỗng

magpie group main
# 8 rung đúng thứ tự mục 5; dòng classifier:
#   workbuddy-ai/hy3
#   effort  auto

magpie group glm
magpie group deepseek
# model opencode-zen-free nằm cuối mỗi group

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
  thức. `magpie plugin update` lên bản hỏng thì 2 rung cuối chết. Cách xử:
  ghim lại bản đang chạy: `magpie plugin add opencode-zen-freex@0.5.16`, rồi
  `magpie-headless-stop && magpie-headless-start`.
- **Free tier có giới hạn riêng.** Zen có thể siết thêm bất cứ lúc nào; khi đó 429 lại
  xuất hiện và ladder tự rơi về 6 rung đầu — vẫn chạy.
- **Classifier lỗi giữa phiên.** Request vẫn 200 (đã đo), chỉ mất tác dụng chọn mức
  reasoning; agent tự dùng mức mặc định.
- **`magpie quota` im lặng với Zen** — không phải lỗi, xem mục 4.

## 10. Hoàn tác

```sh
magpie provider on opencode-zen
magpie provider off opencode-zen-free
git revert <commit> && bash scripts/finish.sh
```

Lệnh thứ ba trả `scripts/setup-groups.sh` và `scripts/setup-settings.sh` về ladder cũ;
`finish.sh` áp lại lên máy. Nếu không muốn revert, sửa tay hai mảng trong
`scripts/setup-groups.sh` rồi chạy `bash scripts/setup-groups.sh --force`.

## 11. Đo lại sau này

So hai provider bằng cùng một model, cùng một lúc:

```sh
magpie provider test opencode-zen      deepseek-v4.1-flash-free
magpie provider test opencode-zen      jev-1.13-free
magpie provider test opencode-zen-free deepseek-v4.1-flash-free
magpie provider test opencode-zen-free glm-5.3-flash-free
```

Kỳ vọng hiện tại: hai dòng `opencode-zen` free → ✗ 429, `jev-1.13-free` → ✓ decide,
hai dòng `opencode-zen-free` → ✓ chat. Nếu `opencode-zen` free bắt đầu trả lời lại thì
Zen đã mở lại free tier cho API key — lúc đó có thể cân nhắc đưa về ladder.
