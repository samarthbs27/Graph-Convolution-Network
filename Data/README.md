# Data — Simulation Input Vectors and Golden References

Input stimuli and expected outputs for the GCN testbenches.
All paths in testbenches assume simulation is launched from the project root (`GCN/`).

| File | Format | Description |
|---|---|---|
| `feature_data.txt` | Binary text, 6×96 | Node feature matrix — 6 nodes, 96 features each |
| `weight_data.txt` | Binary text, 96×3 | Weight matrix — 96 features → 3 output classes |
| `coo_data.txt` | Integer pairs | Sparse adjacency in COO format (row, col per line) |
| `gold_address.txt` | Integer per line | Expected argmax class index per node (ground truth) |
| `golden_transformation_output.txt` | Binary text | Expected Transformation block output for regression testing |
| `gcv_verify.py` | Python script | Software GCN reference — generates and verifies golden outputs |
| `gen_gold_reference_transform.py` | Python script | Generates `golden_transformation_output.txt` from feature/weight data |
