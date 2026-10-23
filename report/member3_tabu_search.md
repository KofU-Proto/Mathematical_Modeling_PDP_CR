# Thành viên 3 — Tabu Search và thực nghiệm

## Phương pháp

Mỗi trạng thái tìm kiếm gồm nghiệm hiện tại, nghiệm tốt nhất toàn cục, hai hàng
đợi tabu FIFO và số vòng không cải thiện. Ở mỗi vòng, chương trình sinh các
láng giềng bằng module phần 2, loại các phép tabu và so sánh makespan. Nếu một
láng giềng cải thiện nghiệm tốt nhất toàn cục, chương trình nhận ngay. Nếu
không, TSR chọn láng giềng redistribute tốt nhất với xác suất `β = 0,3`, còn
lại chọn reroute/reverse tốt nhất; khi một nhóm rỗng thì chọn nhóm còn lại.
TSO chỉ xét reroute/reverse. Đây là quy tắc Algorithm 9 trong luận án 2025.

Kích thước tabu list và số láng giềng theo Bảng 5.2: TSO có `TL_add = ⌊n/8⌋`,
`n_reroute = ⌊n/3⌋`, `n_reverse = ⌊n/9⌋`; TSR có `TL_add = ⌊n/8⌋`,
`TL_redis = ⌊n/15⌋`, `n_reroute = ⌊n/5⌋`, `n_reverse = ⌊n/15⌋`,
`n_redis = ⌊n/15⌋`. Cả hai dừng sau 5.000 vòng, quay về nghiệm tốt nhất sau
300 vòng không cải thiện và tạo nghiệm đầu mới sau 600 vòng. Nghiệm tốt nhất
toàn cục được giữ qua mọi lần restart. Nghiệm đầu và mỗi nghiệm restart là nghiệm
tốt nhất trong 50 lần chạy S-greedy Algorithm 5–6 của luận án, với khoảng chèn
`(1,2)`. Trong một lượt, Algorithm 6 duyệt các cặp (task, robot) theo thời điểm
đến tăng dần, gán đủ robot cho tối đa `kinsert` task và đồng bộ thời điểm kết
thúc của các robot được gán. Hàm trả về `Solution` phần 1, sau đó chuyển sang
`FlowSolution` phần 2 để Tabu Search sử dụng.

## Thiết kế thực nghiệm

- `n ∈ {15,30,50}`, `m ∈ {5,10}`, seed instance `1,2`: 12 cặp TSO/TSR.
- Mỗi cặp dùng cùng tọa độ, số robot yêu cầu và nghiệm đầu. Nhu cầu robot lấy
  đều từ `1..5`; thời gian xử lý là khoảng cách Euclid pickup đến delivery.
- Mỗi nghiệm đầu và restart lấy tốt nhất từ 50 lần S-greedy `(1,2)` với seed cố định.
- Mỗi phiên bản chạy 5.000 vòng. Thời gian đo riêng vòng Tabu Search, gồm các
  lần khởi tạo lại nhưng không gồm 50 lần S-greedy tạo nghiệm đầu dùng chung.
  Bước làm nóng Julia giảm sai lệch do biên dịch lần đầu; máy và phiên bản Julia
  cụ thể ảnh hưởng số giây.
- `runs.csv` ghi từng lượt, `summary.csv` nhóm theo `(n,m)`, `convergence.csv`
  lấy giá trị tốt nhất đang có mỗi 100 vòng và chuẩn hóa theo makespan đầu.

## Kết quả

| n | m | Số cặp TSR tốt hơn / 2 | Makespan TB TSO | Makespan TB TSR | Cải thiện TB mỗi cặp |
|---:|---:|---:|---:|---:|---:|
| 15 | 5 | 0 | 943,96 | 958,01 | −1,51% |
| 15 | 10 | 2 | 537,10 | 517,19 | +3,60% |
| 30 | 5 | 0 | 1661,24 | 1661,24 | 0,00% |
| 30 | 10 | 0 | 835,88 | 861,39 | −3,49% |
| 50 | 5 | 0 | 2595,15 | 2599,98 | −0,19% |
| 50 | 10 | 0 | 1341,00 | 1341,00 | 0,00% |

Tổng cộng TSR tốt hơn ở **2/12 cặp (16,7%)**, bằng ở 4 cặp và kém ở 6 cặp. Trung bình
12 mức cải thiện theo cặp là **−0,26%**. TSR chậm hơn TSO trong cả sáu nhóm
nhỏ này; xem số giây chính xác trong `results/member3/summary.csv`.
Các đồ thị trong `plots/member3/` cho thấy đường hội tụ tính từ incumbent,
tương tự cách chuẩn hóa của Hình 12: 100% là nghiệm đầu, thấp hơn là tốt hơn.

Để kiểm tra ảnh hưởng của kích thước bài toán, chạy thêm **10 instance tự sinh**
với `n=100`, `m=10`, seed `1..10`, 5.000 vòng và cùng quy trình best-of-50
S-greedy. Tại kích thước này TSR tốt hơn ở **7/10** instance, cải thiện trung bình
theo cặp **+0,33%** (min **−0,84%**, max **+2,56%**). Makespan trung bình TSO/TSR
lần lượt là **2362,31 / 2354,32**. Dữ liệu chi tiết ở
`results/member3/synthetic_n100/`. Đây vẫn là tọa độ sinh đều ngẫu nhiên, không
phải instance Li & Lim mà bài báo đã chuyển đổi.

## Phạm vi và bước cải thiện

Kết quả trên **không xác nhận** con số khoảng 1,66% và 8/10 trong Bảng 5 của
bản special issue. Bảng đó dùng các instance PDP Li & Lim đã biến đổi với
100–500 task, 10 instance mỗi kích thước và 10 robot. Thực nghiệm ở đây dùng
instance ngẫu nhiên 15–100 task; nhóm nhỏ chỉ có hai seed. Algorithm 5–6 và
best-of-50 đã được cài, nhưng không có dữ liệu gốc và cách chọn biến thể
S-greedy theo từng kích thước ở đây dùng cố định khoảng `(1,2)`. Các chi tiết
chọn láng giềng của phần 2 cũng có thể khác hiện thực tác giả. Vì vậy không thể dùng
chênh lệch ở đây để kiểm định độ trung thực của kết quả gốc.

Bộ Li & Lim gốc có công khai tại SINTEF. Luận án Chương 2 cho biết tên instance
chuyển đổi có dạng `LC1_x_y-5` (ví dụ `LC1_4_3-5` chứa 200 task), nhưng chưa
cho biết chính xác 10 file được chọn ở mỗi cỡ và seed sinh nhu cầu robot. Ưu tiên
tiếp theo là nhập các file Li & Lim, lưu rõ tên file, depot và seed chuyển đổi,
rồi chạy 10 instance mỗi kích thước lớn với cùng cấu hình. Sau đó lặp nhiều
seed cho heuristic để ước lượng độ biến thiên và kiểm tra lại điều kiện chọn láng
giềng của phần 2. Khi thiếu file đã chuyển đổi của tác giả, chỉ nên gọi kết quả
đó là *tái lập theo mô tả*, không gọi là tái tạo đúng Bảng 5.
