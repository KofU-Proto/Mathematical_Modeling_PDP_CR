# Phần Thành viên 2 — Biểu diễn nghiệm flow-DAG và các neighborhood

Tài liệu này là bản nháp phần *phương pháp* của báo cáo. Nó mô tả cách biểu diễn
nghiệm, ba neighborhood (redistribute, reroute, reverse) và cách nhóm kiểm chứng
cài đặt. Mã nguồn nằm trong `src/flow_graph.jl`, `src/neighborhoods.jl`,
`src/redistribute.jl`, `src/reroute.jl` và `src/reverse.jl` (module
`PDPCRMember2`).

## 1. Ký hiệu

| Ký hiệu | Ý nghĩa |
| :--- | :--- |
| $n$, $m$ | số task, số robot |
| $0$, $n+1$ | depot xuất phát (source) và depot đích (sink), $c_0 = c_{n+1} = 0$ |
| $c_i$ | thời gian xử lý task $i$ (chở hàng từ $p_i$ đến $d_i$) |
| $r_i$ | số robot task $i$ cần |
| $t_{ij}$ | thời gian đi từ $d_i$ đến $p_j$ ($t_{0j}$: depot → $p_j$; $t_{i,n+1}$: $d_i$ → depot) |
| $f_{ij}$ | số robot làm task $j$ ngay sau task $i$ |

## 2. Biểu diễn nghiệm bằng flow-DAG

Một nghiệm là đồ thị có hướng không chu trình $F$ trên tập node
$\{0, 1, \dots, n+1\}$. Mỗi cung $(i, j)$ mang $f_{ij} \in \mathbb{Z}_{>0}$ đơn vị
flow; một đơn vị flow là một robot. Nghiệm hợp lệ khi:

1. $\sum_j f_{0j} = m$ và $\sum_i f_{i,n+1} = m$ (ràng buộc (2)–(3) của MILP);
2. với mọi task $i$: flow vào $=$ flow ra $= r_i$ (ràng buộc (4)–(5));
3. không có cung vào $0$, cung ra từ $n+1$, cung tự lặp;
4. $F$ không có chu trình.

Hàm `validate_flow_solution` kiểm tra đủ bốn điều kiện này và được gọi sau mỗi
phép biến đổi trong các bài kiểm thử.

**Cài đặt.** `FlowProblem` giữ dữ liệu tĩnh ($c$, $r$, ma trận $T$).
`FlowSolution` lưu hai danh sách kề `out[i][j] = in_[j][i] = f_ij`; chỉ cung có
flow dương mới được lưu. Mỗi task có tối đa $r_i$ cung ra, nên duyệt đồ thị tốn
$O(n + |A|)$ thay vì $O(n^2)$ như khi dùng ma trận.

**Chuyển đổi với phần Thành viên 1.**
- `from_solution(problem, instance, solution)`: từ `Solution(order, teams)` sang flow-DAG.
- `from_routes(problem, routes)`: từ tuyến của từng robot.
- `to_routes`, `to_solution`: phân rã flow thành $m$ tuyến robot và đổi ngược lại
  về `Solution`, để dùng được `evaluate_schedule`, `is_feasible` và `visualize_solution`.

## 3. Đánh giá nghiệm: thứ tự topo, $L$, $L^*$, makespan

- **Thứ tự topo** (`topological_order`): thuật toán Kahn, $O(n + |A|)$.
- **Algorithm 1** (`earliest_start`): $L_0 = 0$ và
  $L_j = \max_{i \to j} (L_i + c_i + t_{ij})$. Duyệt node theo thứ tự topo nên khi
  xét $i$ thì $L_i$ đã là giá trị cuối cùng. Lấy $\max$ vì task phải chờ robot đến
  muộn nhất. Makespan là $L_{n+1}$.
- **Algorithm 2** (`longest_to_sink`): $L^*_{n+1} = 0$ và
  $L^*_i = c_i + \max_{i \to j} (t_{ij} + L^*_j)$, duyệt theo thứ tự topo ngược.
- **Độ dài đường qua cung**: $\Delta_{ij} = \bar L_i + t_{ij} + L^*_j$ với
  $\bar L_i = L_i + c_i$. Cung có flow dương với $\Delta_{ij} = C_{max}$ là
  **cung găng** (`critical_arcs`).

Hàm `evaluate` trả về thứ tự cắt, $L$, $\bar L$, $L^*$ và makespan. Thứ tự cắt
được sắp theo $L$ (hòa thì theo thứ tự Kahn). Đây vẫn là một thứ tự topo vì với
mọi cung $i \to j$ ta có $L_j \ge L_i + c_i + t_{ij} \ge L_i$.

## 4. Redistribute neighborhood (Mục 3.1 bài báo)

**Cắt.** Cắt thứ tự topo tại $\zeta \in \{1, \dots, n+1\}$: $\zeta$ node đầu
thuộc $N^{left}$ (luôn chứa source), phần còn lại thuộc $N^{right}$ (luôn chứa
sink). Các hàm tương ứng là `choose_cut`, `split_at`, `cut_flows`; hàm cuối trả
về flow qua lát cắt cùng $\pi^{left}_i$ và $\pi^{right}_j$.

**Nhận xét then chốt.** Không có cung nào đi từ phải sang trái, nên mọi đường
source → sink đi qua lát cắt *đúng một lần*. Do đó
$$C_{max} = \max_{(i,j):\, i \in N^{left},\, j \in N^{right},\, f_{ij} > 0} \Delta_{ij}.$$
Khi chỉ sửa các cung qua lát cắt và giữ nguyên $\pi^{left}$, $\pi^{right}$, thì
$\bar L_i$ ($i$ bên trái) và $L^*_j$ ($j$ bên phải) không đổi. Vì vậy makespan mới
tính được chính xác từ $\Delta$ mà không phải dựng lại lịch. Đồ thị mới cũng
luôn không có chu trình, vì mọi cung mới đều đi từ trái sang phải.

**Algorithm 3** (`redistribute_cut!`) lặp các bước sau:

1. $C_{max} \leftarrow \min\{C_{max}, \max_{f_{ij} > 0} \Delta_{ij}\}$.
2. Tập cung cấm $A_f = \{(i, j) : \Delta_{ij} \ge C_{max}\}$; tập
   $A_{max} = \{(i, j) \in A_f : f_{ij} > 0\}$.
3. Chọn ngẫu nhiên $(i^*, j^*) \in A_{max}$.
4. Tìm dãy $\Gamma = (i^*, j_1, i_2, j_2, \dots, i_K, j^*)$ (`find_gamma`).
   Dãy này đi xen kẽ: bước trái → phải $(i_k, j_k)$ phải **không bị cấm** (cung
   sẽ được tăng flow); bước phải → trái $(i_{k+1}, j_k)$ phải có $f > 0$ (cung sẽ
   bị giảm flow). Cài đặt dùng BFS nên tìm được $\Gamma$ ngắn nhất, độ phức tạp
   $O(|N^{left}| \cdot |N^{right}|)$.
5. Đặt $\delta = \min\{f_{i^* j^*}, \min_k f_{i_{k+1} j_k}\}$. Giảm $\delta$ trên
   $(i^*, j^*)$ và các cung $(i_{k+1}, j_k)$, tăng $\delta$ trên các cung
   $(i_k, j_k)$. Bản chất đây là dời flow dọc một chu trình xen kẽ trong đồ thị
   hai phía, nên flow vào/ra của mọi node được giữ nguyên.
6. Dừng khi không tìm được $\Gamma$. Khi đó cung găng $(i^*, j^*)$ không thể bỏ
   được và $C_{max}$ không giảm thêm.

Thuật toán luôn dừng: tổng flow trên các cung cấm giảm thực sự sau mỗi vòng,
trong khi $C_{max}$ không tăng. Makespan sau redistribute không bao giờ lớn hơn
trước.

**Kiểm chứng bằng Ví dụ 3 của bài báo.** Cắt tại $\zeta = 4$, với
$N^{left} = \{S, A, B, C\}$, $N^{right} = \{D, E, S'\}$, flow ban đầu
$f_{AD} = 4$, $f_{BE} = 1$, $f_{CE} = 2$, và $\Delta$ lấy từ Bảng 3. Chương trình
cho đúng kết quả của bài báo: $(i^*, j^*) = (C, E)$, $\Gamma = (C, D, A, E)$,
$\delta = 2$, $C_{max}$: $24 \to 22$, và vòng sau không tìm được $\Gamma$ từ $C$
tới $D$.

## 5. Reroute neighborhood (Mục 3.2, theo [10])

Chọn hai cung $(i, j)$, $(u, v)$ có flow dương và một lượng $q$:
$$f_{ij} \mathrel{-}= q,\quad f_{uv} \mathrel{-}= q,\quad f_{iv} \mathrel{+}= q,\quad f_{uj} \mathrel{+}= q.$$
Bảo toàn flow tự động được giữ. Phép biến đổi bị loại nếu $i = u$ hoặc $j = v$
(không thay đổi gì), nếu $i = v$ hoặc $u = j$ (cung tự lặp), hoặc nếu tạo chu
trình.

Ba biến thể (`reroute_neighbors(...; variant)`):
- `:full` ($N_{reroute}$): mọi cặp cung, mọi $q \in \{1, \dots, \min(f_{ij}, f_{uv})\}$;
- `:max_ca` ($N^{max,ca}_{reroute}$): $(i, j)$ là cung găng, $q$ lấy tối đa;
- `:max_ca_delta` ($N^{max,ca,\delta}_{reroute}$, mặc định): chỉ dùng cung găng có
  $t_{ij}$ lớn nhất.

## 6. Reverse neighborhood (Mục 3.2, theo [10])

Đảo chiều cung găng $(i, j)$ giữa hai task, với $q = f_{ij}$: sau biến đổi
$f_{ji} = q$ và $f_{ij} = 0$. Để giữ bảo toàn flow:

- Task $i$ nhận thêm $q$ flow từ $j$, nên phải bớt $q$ flow vào $i$ từ tập tiền
  nhiệm $U$ và chuyển chúng vào $j$: $f_{ui} \mathrel{-}= a_u$, $f_{uj} \mathrel{+}= a_u$.
- Task $j$ gửi thêm $q$ flow sang $i$, nên phải bớt $q$ flow ra từ $j$ tới tập hậu
  nhiệm $V$ và cho chúng đi ra từ $i$: $f_{jv} \mathrel{-}= b_v$, $f_{iv} \mathrel{+}= b_v$.

$U$ được chọn theo thời điểm robot tới $i$ tăng dần ($\bar L_u + t_{ui}$), còn
$V$ theo $t_{jv}$ tăng dần. Cả hai là tập tối thiểu có tổng flow $\ge q$; phần
tử cuối chỉ đóng góp phần còn thiếu ($q_a$, $q_b$ trong bài báo). Phép biến đổi
bị loại nếu tạo chu trình.

## 7. Giao diện cho Tabu Search (Thành viên 3)

Mỗi láng giềng là một `Candidate(move, changes, before, after)`, trong đó
`changes` là danh sách $(i, j, \Delta f)$. Láng giềng được đánh giá **tại chỗ**:
áp dụng thay đổi, tính makespan, rồi hoàn tác (`try_changes`). Nhờ đó không phải
sao chép đồ thị; chỉ khi Tabu Search chọn một láng giềng mới gọi
`materialize(s, c)` để tạo nghiệm mới.

```julia
include("src/PDPCR.jl"); using .PDPCRMember1, .PDPCRMember2
s     = from_solution(FlowProblem(instance), instance, greedy_initial_solution(instance))
cands = generate_neighbors(s; config=default_config(n, :TSR), rng)
best  = argmin(c -> c.after, filter(c -> !is_tabu(c.move, tl_add, tl_redis), cands))
s     = materialize(s, best)
append!(tl_add, removed_arcs(best.move))   # hoặc push!(tl_redis, best.move.zeta)
```

`default_config(n, :TSO | :TSR)` lấy số láng giềng theo Bảng 4 của bài báo. Có
thể gọi `neighborhood_name(c.move)` để biết láng giềng đến từ neighborhood nào,
phục vụ quy tắc chọn theo xác suất $\beta$.

**Thời gian sinh láng giềng** (cấu hình TSR, một lần đánh giá, máy thử nghiệm):
khoảng 0,2 ms với $n = 50$, 1,8 ms với $n = 150$ và 15 ms với $n = 500$ mỗi vòng.

## 8. Kiểm thử

Chạy `julia --project=. test/test_member2.jl`. Bộ kiểm thử gồm:

- Ví dụ 1 bài báo: $L_2 = 7$, $L_3 = 10$, $L_1 = 15{,}5$ (robot từ task 2 phải
  chờ), makespan $= 21{,}5$, các cung găng.
- Ví dụ 3 bài báo: tái hiện từng bước của Algorithm 3 như mục 4.
- 40 instance ngẫu nhiên ($n = 6$–$30$, $m = 2$–$8$):
  - mọi láng giềng đều hợp lệ;
  - makespan dự đoán của láng giềng khớp với makespan đánh giá lại, và khớp với
    evaluator của Thành viên 1;
  - redistribute không bao giờ làm makespan tệ hơn;
  - chuyển `Solution` ↔ flow-DAG không làm mất thông tin.

## 9. Ghi chú về bài báo

Khi cài đặt, nhóm phát hiện vài chỗ trong bài báo có vẻ là lỗi đánh máy:

- Algorithm 2 ghi output là "$L_j$"; đúng ra phải là $L^*_j$.
- Công thức reroute ghi $f'_{vj} = f_{vj} + q$; đúng ra phải là $f'_{uj}$.
- Quy tắc tabu cho reroute ghi "$(i', u')$ hoặc $(u', j')$ thuộc $TL_{add}$".
  Nhóm hiểu là phép biến đổi bị tabu nếu nó **thêm lại** một cung vừa bị xóa,
  tức $(i', v')$ hoặc $(u', j')$ thuộc $TL_{add}$. Cách hiểu này nhất quán với
  quy tắc của reverse ($(j', i') \in TL_{add}$).
- Ví dụ 3 viết $\delta = \min\{f_{CE}, f_{AD}\} = \min\{4, 2\}$, trong khi Hình 9(a)
  và kết quả $f_{CE} = 2 - 2 = 0$, $f_{AD} = 4 - 2 = 2$ cho thấy $f_{CE} = 2$ và
  $f_{AD} = 4$. Kết quả $\delta = 2$ không đổi.
