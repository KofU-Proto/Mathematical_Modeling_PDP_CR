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
toàn cục được giữ qua mọi lần restart. Cơ chế tạo nghiệm restart lấy ngẫu nhiên
một trong ba task có thời điểm hoàn tất sớm nhất, rồi chọn đội robot đến sớm
nhất; nghiệm đầu của hai thuật toán vẫn là cùng nghiệm greedy phần 1.

## Thiết kế thực nghiệm

- `n ∈ {15,30,50}`, `m ∈ {5,10}`, seed instance `1,2`: 12 cặp TSO/TSR.
- Mỗi cặp dùng cùng tọa độ, số robot yêu cầu và nghiệm đầu. Nhu cầu robot lấy
  đều từ `1..5`; thời gian xử lý là khoảng cách Euclid pickup đến delivery.
- Mỗi phiên bản chạy 5.000 vòng. Thời gian đo sau bước làm nóng Julia để giảm
  sai lệch do biên dịch lần đầu. Máy và phiên bản Julia cụ thể ảnh hưởng số giây.
- `runs.csv` ghi từng lượt, `summary.csv` nhóm theo `(n,m)`, `convergence.csv`
  lấy giá trị tốt nhất đang có mỗi 100 vòng và chuẩn hóa theo makespan đầu.

## Kết quả

| n | m | Số cặp TSR tốt hơn / 2 | Makespan TB TSO | Makespan TB TSR | Cải thiện TB mỗi cặp |
|---:|---:|---:|---:|---:|---:|
| 15 | 5 | 2 | 1051,09 | 963,62 | +8,35% |
| 15 | 10 | 2 | 571,60 | 516,47 | +9,48% |
| 30 | 5 | 0 | 1803,43 | 1867,12 | −3,98% |
| 30 | 10 | 1 | 886,39 | 906,89 | −1,84% |
| 50 | 5 | 0 | 2694,53 | 2700,28 | −0,23% |
| 50 | 10 | 1 | 1412,60 | 1394,43 | +1,36% |

Tổng cộng TSR tốt hơn ở **6/12 cặp (50%)**, bằng ở 2 cặp và kém ở 4 cặp. Trung bình
12 mức cải thiện theo cặp là **+2,19%**. TSR chậm hơn TSO trong cả sáu nhóm
nhỏ này; xem số giây chính xác trong `results/member3/summary.csv`.
Các đồ thị trong `plots/member3/` cho thấy đường hội tụ tính từ incumbent,
tương tự cách chuẩn hóa của Hình 12: 100% là nghiệm đầu, thấp hơn là tốt hơn.

## Phạm vi và bước cải thiện

Kết quả trên **không xác nhận** con số khoảng 1,66% và 8/10 trong Bảng 5 của
bản special issue. Bảng đó dùng các instance PDP Li & Lim đã biến đổi với
100–500 task, 10 instance mỗi kích thước và 10 robot. Thực nghiệm ở đây dùng
instance ngẫu nhiên 15–50 task và chỉ hai seed mỗi nhóm. Nghiệm đầu của luận án
được chọn từ 50 lần chạy S-greedy theo Algorithm 5–6; code hiện dùng greedy
phần 1 và chỉ dùng greedy có ngẫu nhiên để restart. Thư viện Julia và phần 2
cũng có thể khác chi tiết hiện thực Python của tác giả. Vì vậy không thể dùng
chênh lệch ở đây để kiểm định độ trung thực của kết quả gốc.

Ưu tiên tiếp theo là cài chính xác Algorithm 5–6 S-greedy, nhập các instance
Li & Lim gốc và quy trình biến đổi, rồi chạy 10 instance mỗi kích thước lớn
với cùng phần cứng và cấu hình. Sau đó nên lặp nhiều seed cho heuristic để
ước lượng độ biến thiên và kiểm tra lại điều kiện chọn láng giềng của phần 2.
