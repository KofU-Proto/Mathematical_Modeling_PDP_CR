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
tốt nhất trong 50 lần chạy S-greedy Algorithm 5–6 của luận án. Bộ tự sinh dùng
khoảng chèn `(1,2)`; bộ Li & Lim dùng `(1,3)` ở cỡ 100 theo Bảng 4.3 của luận án
và `(1,2)` ở các cỡ khác. Bảng 4.3 không có cỡ 500, nên `(1,2)` tại cỡ này
là giả định. Trong một lượt, Algorithm 6 duyệt các cặp (task, robot) theo thời điểm
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

## Li & Lim theo mô tả luận án

Đã nhập 50 file `LC1_x_1..10` với `x ∈ {2,4,6,8,10}` từ
[bản sao PyVRP](https://github.com/PyVRP/Instances/tree/main/PDPTW) của
[benchmark SINTEF](https://www.sintef.no/projectweb/top/pdptw/li-lim-benchmark/).
Mỗi cặp pickup-delivery thành một task PDP-CR; tọa độ và depot
giữ nguyên; thời gian xử lý bằng khoảng cách Euclid; nhu cầu robot lấy đều từ
`1..5` với seed chuyển đổi 42. Các file, hash SHA-256 và nguồn được ghi ở
`data/li_lim_raw/`. Cỡ `n` trong bảng là tên lớp danh nghĩa; số cặp thực tế
được ghi ở `actual_tasks` trong `runs.csv` và dùng tính số láng giềng, tabu size.
Mỗi cặp TSO/TSR dùng cùng instance, cùng nghiệm đầu và 5.000 vòng. Seed tìm
kiếm là thứ tự file khi sắp tên trong từng lớp (1–10). Bảng 4.2 của luận án
liệt kê đích danh `LC1_2_1..10` và `LC1_4_1..10` cho thí nghiệm greedy; chưa
có danh sách 10 file của Bảng 5.

| n | TSR tốt hơn / 10 | Gap trung bình theo luận án | Paper Bảng 5: số tốt hơn | Paper Bảng 5: gap |
|---:|---:|---:|---:|---:|
| 100 | 8 | +1,87% | 8 | +2,35% |
| 200 | 10 | +1,86% | 8 | +1,21% |
| 300 | 8 | +1,83% | 7 | +0,51% |
| 400 | 6 | +0,63% | 9 | +1,71% |
| 500 | 8 | +1,40% | 8 | +2,53% |

Trung bình năm lớp là **+1,52%**, gần con số **+1,66%** của paper; từng lớp
vẫn khác, đặc biệt cỡ 400. Gap ở bảng này tính theo công thức được in trong
luận án: `100 × (TSO − TSR) / TSR`. Các `summary.csv` gốc còn lưu chỉ số
`100 × (TSO − TSR) / TSO`, nên không so trực tiếp cột đó với bảng trên.

Đây là phép **tái lập theo mô tả**, chưa phải tái tạo đúng Bảng 5: seed sinh nhu
cầu robot, file đã chuyển đổi và 10 instance tác giả chọn cho từng hàng chưa
được công bố. S-greedy của ta trên `LC1_2_1` với seed 42 cho nghiệm đầu 875,1
ở biến thể `(1,2)`, trong khi Bảng 4.2 báo best-of-50 là 917,1; chỉ riêng
điểm đối chiếu này đã xác nhận dữ liệu hoặc ngẫu nhiên hóa chưa trùng tác giả.
Thời gian chạy cũng không so được trực tiếp vì mã Julia và môi trường khác
Python 3.9 trên Intel i5-8400 của paper.

## Phân tích ứng viên redistribute không đổi nghiệm

Trong 10 nghiệm đầu `LC1_2` kiểm tra bằng `(1,2)`, **948/1.064** vị trí cắt
(89,1%) trả về `changes=[]`: flow không đổi nhưng mã ban đầu vẫn tính là một
ứng viên redistribute. Có thêm tùy chọn
`--redistribute-skip-unchanged=true`: thử các vị trí cắt cho đến khi thu đủ
số ứng viên thật sự đổi flow hoặc hết vị trí. Mặc định cũ vẫn được giữ để đối
chiếu. Paper không mô tả rõ có bỏ ứng viên không đổi hay không, nên kết quả tùy
chọn này là phân tích độ nhạy, không được trình bày như tái tạo paper.

Với cỡ 100 và đúng S-greedy `(1,3)`, chế độ mặc định cho **8/10, +1,87%**;
chế độ bỏ ứng viên không đổi cho **9/10, +3,01%** theo cùng công thức luận án.
Các kết quả chi tiết nằm trong các thư mục `results/member3/li_lim_lc1_*`.
