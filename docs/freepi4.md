# FreePi4 — plugin riêng cho tài khoản FreePi thứ năm

`FreePi4` là một provider **riêng** của magpie, dùng để đăng nhập một tài khoản
[free-pi](https://api.freepi.ai) **khác** với ba tài khoản còn lại. Nó không
phải bản sao của `freepi` hay `free-pi`: mã nguồn plugin nằm trong repo private
<https://github.com/Duc-Nguyen-739/FreePiLogin4>, có icon riêng, mô tả tiếng Việt,
và lưu trạng thái trong thư mục `~/.freepi4`.

Repo đó chứa hai thứ:

| Thư mục | Nội dung |
|---|---|
| `index.mjs`, `lib/`, `package.json` | plugin magpie `magpie-freepi4-auth` → provider `freepi4` |
| `upstream/FreePi2API/` | bản sao đầy đủ mã nguồn [FreePi2API](https://github.com/ErfanBagheri404/FreePi2API) (proxy Python stdlib, **không phải** plugin magpie) |

## Cài trên máy khác

Repo là **private**. Máy mới cần đọc được repo bằng `gh` (hoặc clone sẵn), rồi cài
từ thư mục local:

```sh
gh auth login                      # tài khoản có quyền đọc Duc-Nguyen-739/FreePiLogin4
gh repo clone Duc-Nguyen-739/FreePiLogin4 ~/.local/src/FreePiLogin4
magpie plugin add ~/.local/src/FreePiLogin4
```

Nếu đã có bản clone:

```sh
git -C ~/.local/src/FreePiLogin4 pull --ff-only
magpie plugin add ~/.local/src/FreePiLogin4
```

`magpie plugin add` với cùng đường dẫn sẽ nạp lại mã plugin tại chỗ; không cần
gỡ plugin, không mất token đăng nhập.

Kiểm tra:

```sh
magpie plugin list | grep -A1 FreePi4
# /home/<bạn>/.local/src/FreePiLogin4  on
#   freepi4 (FreePi4, 18 models)  not signed in · magpie plugin login freepi4
```

`magpie providers` **chưa** hiện FreePi4 trước khi đăng nhập — xem mục
“Vì sao `magpie providers` không thấy FreePi4” bên dưới.

## Đăng nhập

Trên máy có trình duyệt:

```sh
magpie plugin login freepi4
```

Trên Cloud Shell / máy headless, dùng web UI:

1. `openmagpie`
2. Settings → Providers → Add provider → **From plugins** → **FreePi4**
3. Chọn **Đăng nhập bằng mã thiết bị GitHub**, mở link GitHub và nhập mã.

Token nằm trong `~/.config/magpie/plugin-auth.json` ở khoá `freepi4`; không đụng
token của `freepi` / `free-pi`.

## Dùng

```sh
magpie provider test freepi4 deepseek-v4.1-flash
magpie provider models freepi4
magpie group set main models+=freepi4/deepseek-v4.1-flash
```

Model hiện ra dưới dạng `freepi4/<model-id>`, ví dụ
`freepi4/deepseek-v4.1-flash`.

## Lưu trữ tách biệt

| Thứ | Nơi lưu |
|---|---|
| Token | `~/.config/magpie/plugin-auth.json`, khoá `freepi4` |
| Session id thiết bị | `~/.freepi4/session-id` — UUID ngẫu nhiên, file `0600`, thư mục `0700` |
| Đổi chỗ lưu | `FREEPI4_HOME=/đường/dẫn/khác` |

`~/.freepi4` khác hoàn toàn `~/.free-pi/agent` của `free-pi-cli` và không dùng
chung hằng số `magpie-freepi` của plugin `freepi`. Mỗi máy cài sinh một UUID
riêng, nên hai máy không gửi cùng `x-session-id`.

magpie không cho plugin tự chọn file credential: token luôn nằm trong
`plugin-auth.json` theo provider id. Vì vậy “hai kho khác nhau” ở đây là **hai
khoá credential độc lập** cộng với **hai thư mục trạng thái độc lập**, không phải
hai file token rời.

## Vì sao `magpie providers` không thấy FreePi4

`magpie providers` chỉ liệt kê provider đã có cấu hình hoặc đã đăng nhập. Một
provider mới từ plugin, chưa có auth, chỉ hiện ở:

- `magpie plugin list` (dòng `freepi4 (FreePi4, …)`), và
- web UI `/api/providers`, mục `plugins`.

Sau khi đăng nhập thành công, `freepi4` xuất hiện trong `magpie providers` và
`magpie models`. Gateway đang chạy đọc `providers.json` động, nên route
`freepi4/*` dùng được ngay, không phải restart `magpie serve`.

## Vướng mắc đã gặp và cách xử lý

### 1. `magpie plugin add github:…` trả 404 với repo private

Đây là vướng mắc lớn nhất. Các cách sau **đều không chạy** với repo private:

```sh
magpie plugin add github:Duc-Nguyen-739/FreePiLogin4
magpie plugin add git+https://github.com/Duc-Nguyen-739/FreePiLogin4.git
GITHUB_TOKEN="$(gh auth token)" magpie plugin add github:Duc-Nguyen-739/FreePiLogin4
```

Lý do: magpie gọi bun 1.4.4 đi kèm (`~/.cache/magpie/bun/1.4.4/magpie-bun`), và
bun đổi mọi spec GitHub thành một lần tải:

```
GET https://api.github.com/repos/Duc-Nguyen-739/FreePiLogin4/tarball/
```

Lần tải đó **không gửi header `Authorization`**. Với repo public, GitHub trả
tarball; với repo private, GitHub trả `404` (cố tình không tiết lộ repo có tồn
tại hay không). Đã thử `GITHUB_TOKEN` và `GITHUB_ACCESS_TOKEN`; bun vẫn không
gửi token. `curl` cùng URL **có** token trả `302`, nên token không phải vấn đề —
vấn đề là bun không dùng token cho endpoint tarball.

Cách chạy được:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin4 ~/.local/src/FreePiLogin4
magpie plugin add ~/.local/src/FreePiLogin4
```

`gh` dùng credential helper của chính nó, nên chỉ cần `gh auth login` một lần.
`scripts/plugins.sh` của repo shell-cloud làm đúng chuỗi này và chỉ cảnh báo
(nếu thiếu quyền) thay vì làm hỏng cả bộ cài.

### 2. `git+ssh` chạy được nhưng không tiện cho máy mới

Đã thử tạo deploy key riêng, thêm vào repo, chạy `ssh-agent` rồi:

```sh
magpie plugin add git+ssh://git@github.com/Duc-Nguyen-739/FreePiLogin4.git
```

Cách này cài được, nhưng mỗi máy phải có khoá SSH riêng và phải cấu hình
`~/.ssh/config` hoặc agent. Vì vậy nó chỉ là phương án dự phòng, không phải cách
chính. Nếu dùng, đừng commit khoá; thêm public key vào repo bằng
`gh repo deploy-key add`.

### 3. Plugin đã cài nhưng chưa thấy provider

Ban đầu `magpie plugin list` thấy `freepi4`, nhưng `magpie providers` và
`magpie models` không thấy. Nguyên nhân: provider chưa có auth. Sau khi đăng
nhập, mọi thứ hiện ra. Không cần restart gateway.

### 4. Ad gate `403 {"code":"ads_required"}`

free-pi trả 403 cho completion nếu tài khoản chưa báo banner impression gần đây.
`magpie-freepi-auth` đã làm việc này; `magpie-free-pi` thì không, nên phải vá
bằng `scripts/patch-free-pi-ads.mjs`. FreePi4 **đã tích hợp sẵn** luồng:

```
GET /ads/next?slot=banner  →  POST /ads/impression
```

Không cần patch. Nếu completion trả 403 `ads_required`, kiểm tra log plugin và
chạy `magpie provider test freepi4 deepseek-v4.1-flash`.

### 5. Client version 426

Upstream có thể nâng `min` client version và trả `426 your free-pi-cli is below
the required minimum`. FreePi4 đọc `/client-version` và tự canh
`x-client-version` theo `latest`, không ghim số như bản `free-pi` cũ. Nếu vẫn
426, chạy `magpie plugin add ~/.local/src/FreePiLogin4` để nạp bản mới.

### 6. Sáu tài khoản trên cùng một upstream

`freepi`, `freepi2`, `freepi3`, `freepi4`, `freepi5` và `freepi6` cùng gọi `api.freepi.ai`, nhưng là sáu tài khoản
khác nhau:

| Provider | Tài khoản trên máy này |
|---|---|
| `freepi` | `Duc-Nguyen-739` |
| `freepi2` | `huenguyen-code` |
| `freepi3` | `hoangphat-coder` |
| `freepi4` | `phucth2002-spec` |
| `freepi5` | `ngocson-coder` |
| `freepi6` | `haiquan-tbs` |

Tên account là ảnh chụp lúc đăng nhập; đăng nhập lại có thể đổi. Kiểm tra bằng
`GET /me` hoặc `magpie accounts`.

### 6b. 429 `concurrent` — một slot, hàng đợi

FreePi chỉ cho **một request sinh token** trên mỗi account tại một thời điểm.
Request thứ hai đến khi request trước còn stream trả:

```json
{"code":"concurrent","message":"one request at a time, 12,412 credits left today","limit":"concurrent"}
```

Đây **không phải hết credit**. Đặt magpie xếp hàng thay vì gửi song song:

```sh
magpie provider account-concurrency freepi4 phucth2002-spec 1
magpie provider queue freepi4 32 0
magpie provider rpm freepi4 off
```

- `account-concurrency … 1`: mỗi account chỉ một request ra upstream.
- `queue … 32 0`: tối đa 32 request chờ; `0` = chờ bao lâu cũng được.
- `rpm … off`: không giới hạn thêm request/phút.

Magpie giữ slot đến khi **đọc hết reply** rồi mới gửi request kế; request đang chờ
không bị tính là lỗi và không làm account bị rest. Kiểm tra:

```sh
magpie provider account-concurrency freepi4   # at most 1 at once (its own)
magpie provider queue freepi4                 # 32 waiting, as long as it takes
```

Plugin cũng đặt `magpie.maxConcurrency = 1` trong `package.json` để account mới
mặc định một slot. Ngoài ra plugin giữ **1 giây** sau khi body đóng và retry
429 `concurrent` tối đa **5 lần** (2/4/8/15/30 giây, jitter ±20%) để xử lý
trường hợp server còn giữ lock sau khi client đã đọc hết reply. Nếu account đổi
tên sau khi đăng nhập lại, đặt lại `account-concurrency` với tên mới.

Lưu ý: hàng đợi giữ turn, nhưng OpenCode có timeout riêng (~2 phút). Vì vậy vẫn
giữ **một session review** tại một thời điểm và không gửi tin nhắn mới vào session
đang chạy; nếu không, request cuối có thể bị OpenCode huỷ (499), không phải 429.

FreePi4 tách `x-session-id`, token, thư mục trạng thái và budget. **Không tách
được IP**: nếu cả sáu đi ra cùng một địa chỉ mạng, upstream vẫn thấy chúng sau
cùng một IP, và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server
không phát hiện. Nếu cần khác IP, đặt proxy riêng cho FreePi4:

```sh
magpie plugin options ~/.local/src/FreePiLogin4 '{"proxy":"http://proxy-host:8080"}'
magpie plugin options ~/.local/src/FreePiLogin4 off   # bỏ proxy
```

Đây là biện pháp giảm khả năng bị gộp, không phải bảo đảm tuyệt đối.

### 7. Icon và mô tả

- Icon FreePi4 là SVG riêng: nền tím → hồng cánh sen → hồng đậm, tia chớp trắng,
  huy hiệu số **4** màu vàng. Không dùng icon của freepi.ai.
- `magpie.name` = `FreePi4`; `magpie.summary.vi` và `description` viết tiếng Việt.
- Nhãn phương thức đăng nhập chỉ có `vi`; không có bản tiếng Anh để tránh UI
  tiếng Anh hiển thị mô tả khác.
- Tên model vẫn là id gốc của upstream (`deepseek-v4.1-flash`, …) — đó là id
  kỹ thuật, không phải mô tả.

### 8. Token và bảo mật

- Token không nằm trong repo. `plugin-auth.json` và `~/.freepi4/session-id` chỉ
  nằm trên máy.
- `.gitignore` của repo chặn `node_modules/`, `auth.json`, `__pycache__/`, log.
- Không chạy `magpie` bằng `sudo`; không sửa tay `plugin-auth.json`.
- Repo private: chỉ tài khoản được mời mới đọc được. Khi chia sẻ máy, đăng xuất
  `gh` nếu không muốn người khác clone được.

## Kiểm tra nhanh

```sh
magpie plugin list | grep -A1 FreePi4
magpie providers | grep FreePi4
magpie models | grep '^freepi4/'
magpie provider test freepi4 deepseek-v4.1-flash
bash scripts/doctor.sh | grep FreePi4
```

Kỳ vọng:

```
freepi4 (FreePi4, 18 models)  signed in as ngaynaochavao73999-code
✓ FreePi4: session id riêng (~/.freepi4, quyền 600)
✓ FreePi4 đã đăng nhập
```

## Cập nhật và gỡ

```sh
git -C ~/.local/src/FreePiLogin4 pull --ff-only
magpie plugin add ~/.local/src/FreePiLogin4
```

Gỡ plugin:

```sh
magpie plugin logout freepi4     # tuỳ chọn: xoá token khỏi plugin-auth.json
magpie plugin rm ~/.local/src/FreePiLogin4
```

## Giới hạn

Đây là plugin cộng đồng **không chính thức**, dịch ngược từ `free-pi-cli`.
Upstream đổi giao thức là plugin có thể hỏng. Nó không được FreePi bảo trợ, và
việc dùng nhiều tài khoản có thể vi phạm điều khoản của FreePi; tự cân nhắc rủi
ro bị khoá tài khoản. Mã nguồn FreePi2API trong `upstream/` giữ nguyên bản quyền
của tác giả gốc.
