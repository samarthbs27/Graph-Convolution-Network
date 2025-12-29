"""
GCN Computation Verification Script
Computes intermediate values for Transformation, Combination, and Argmax blocks
"""

import numpy as np

def read_feature_data(filename='Data/feature_data.txt'):
    """Read feature matrix from file (6x96, 5-bit values in binary)"""
    features = []
    with open(filename, 'r') as f:
        for line in f:
            row = []
            values = line.strip().split()
            for val in values:
                # Convert binary string to decimal
                row.append(int(val, 2))
            features.append(row)
    return np.array(features, dtype=np.int32)

def read_weight_data(filename='Data/weight_data.txt'):
    """Read weight matrix from file (3x96, 5-bit values in binary)"""
    weights = []
    with open(filename, 'r') as f:
        for line in f:
            row = []
            values = line.strip().split()
            for val in values:
                # Convert binary string to decimal
                row.append(int(val, 2))
            weights.append(row)
    return np.array(weights, dtype=np.int32)

def read_coo_data(filename='Data/coo_data.txt'):
    """Read COO sparse matrix (2 rows x 6 columns, 3-bit values in binary)"""
    coo = []
    with open(filename, 'r') as f:
        for line in f:
            row = []
            values = line.strip().split()
            for val in values:
                # Convert binary string to decimal (1-indexed node numbers)
                row.append(int(val, 2))
            coo.append(row)
    return np.array(coo, dtype=np.int32)

def read_gold_output(filename='Data/gold_address.txt'):
    """Read expected gold output (6 values, 2-bit binary)"""
    gold = []
    with open(filename, 'r') as f:
        for line in f:
            val = line.strip()
            if val:
                gold.append(int(val, 2))
    return np.array(gold, dtype=np.int32)

def compute_transformation(features, weights):
    """
    Compute FM_WM = Features (6x96) × Weights.T (96x3)
    Result: 6x3 matrix
    """
    print("\n" + "="*60)
    print("TRANSFORMATION BLOCK: FM_WM = Features × Weights^T")
    print("="*60)
    
    # Weights need to be transposed: (3x96) -> (96x3)
    weights_t = weights.T
    
    # Matrix multiplication
    fm_wm = np.dot(features, weights_t)
    
    print(f"\nFeatures shape: {features.shape}")
    print(f"Weights shape: {weights.shape}")
    print(f"Weights^T shape: {weights_t.shape}")
    print(f"FM_WM shape: {fm_wm.shape}")
    
    print("\nFM_WM Matrix (Feature × Weight):")
    print("         Col0      Col1      Col2")
    print("-" * 40)
    for i in range(fm_wm.shape[0]):
        print(f"Row{i}:  {fm_wm[i,0]:6d}    {fm_wm[i,1]:6d}    {fm_wm[i,2]:6d}")
    
    return fm_wm

def compute_combination(fm_wm, coo):
    """
    Compute ADJ_FM_WM using COO sparse adjacency matrix
    For each edge (src, dst) in COO: ADJ_FM_WM[dst] += FM_WM[src]
    """
    print("\n" + "="*60)
    print("COMBINATION BLOCK: Graph Aggregation")
    print("="*60)
    
    # Initialize result matrix (same size as FM_WM)
    adj_fm_wm = np.zeros_like(fm_wm)
    
    # Extract source and destination from COO
    # Row 0 = sources (1-indexed), Row 1 = destinations (1-indexed)
    sources = coo[0] - 1  # Convert to 0-indexed
    destinations = coo[1] - 1  # Convert to 0-indexed
    
    print(f"\nCOO Matrix (1-indexed):")
    print(f"Sources:      {coo[0]}")
    print(f"Destinations: {coo[1]}")
    print(f"\nConverted to 0-indexed:")
    print(f"Sources:      {sources}")
    print(f"Destinations: {destinations}")
    
    print(f"\nProcessing {len(sources)} edges:")
    
    # Process each edge
    for edge_idx in range(len(sources)):
        src = sources[edge_idx]
        dst = destinations[edge_idx]
        
        print(f"\nEdge {edge_idx}: Node {src} → Node {dst}")
        print(f"  Adding FM_WM[{src}] = {fm_wm[src]} to ADJ_FM_WM[{dst}]")
        print(f"  Before: ADJ_FM_WM[{dst}] = {adj_fm_wm[dst]}")
        
        # Accumulate: ADJ[dst] += FM_WM[src]
        adj_fm_wm[dst] += fm_wm[src]
        
        print(f"  After:  ADJ_FM_WM[{dst}] = {adj_fm_wm[dst]}")
    
    print("\n" + "-"*60)
    print("Final ADJ_FM_WM Matrix (After Graph Aggregation):")
    print("         Col0      Col1      Col2")
    print("-" * 40)
    for i in range(adj_fm_wm.shape[0]):
        print(f"Row{i}:  {adj_fm_wm[i,0]:6d}    {adj_fm_wm[i,1]:6d}    {adj_fm_wm[i,2]:6d}")
    
    return adj_fm_wm

def compute_argmax(adj_fm_wm):
    """
    Compute argmax for each row
    Returns the column index with maximum value for each node
    """
    print("\n" + "="*60)
    print("ARGMAX BLOCK: Find Maximum Column for Each Node")
    print("="*60)
    
    argmax_results = []
    
    print("\nNode  [Col0, Col1, Col2]           Max Value  Max Column (0-indexed)")
    print("-" * 75)
    
    for node_idx in range(adj_fm_wm.shape[0]):
        row = adj_fm_wm[node_idx]
        max_value = np.max(row)
        max_column = np.argmax(row)
        
        print(f"{node_idx}     [{row[0]:6d}, {row[1]:6d}, {row[2]:6d}]    {max_value:6d}     {max_column}")
        
        argmax_results.append(max_column)
    
    return np.array(argmax_results, dtype=np.int32)

def compute_argmax_highest_nonzero(adj_fm_wm):
    """
    Alternative: Return highest column index that has non-zero value
    """
    print("\n" + "="*60)
    print("ALTERNATIVE ARGMAX: Highest Non-Zero Column Index")
    print("="*60)
    
    results = []
    
    print("\nNode  [Col0, Col1, Col2]           Highest Non-Zero Column")
    print("-" * 70)
    
    for node_idx in range(adj_fm_wm.shape[0]):
        row = adj_fm_wm[node_idx]
        
        # Find highest index with non-zero value
        highest_nonzero = -1
        for col_idx in range(len(row)-1, -1, -1):
            if row[col_idx] != 0:
                highest_nonzero = col_idx
                break
        
        # If all zeros, return 0
        if highest_nonzero == -1:
            highest_nonzero = 0
        
        print(f"{node_idx}     [{row[0]:6d}, {row[1]:6d}, {row[2]:6d}]    {highest_nonzero}")
        
        results.append(highest_nonzero)
    
    return np.array(results, dtype=np.int32)

def compute_argmax_1indexed(adj_fm_wm):
    """
    Compute argmax with 1-indexed output (1, 2, 3 for columns)
    Special case: 0 if all values are zero
    """
    print("\n" + "="*60)
    print("ALTERNATIVE ARGMAX: 1-Indexed Column Numbers")
    print("="*60)
    
    results = []
    
    print("\nNode  [Col0, Col1, Col2]           Max Column (1-indexed)")
    print("-" * 70)
    
    for node_idx in range(adj_fm_wm.shape[0]):
        row = adj_fm_wm[node_idx]
        
        # Check if all zeros
        if np.all(row == 0):
            result = 0
        else:
            max_column = np.argmax(row)
            result = max_column + 1  # Convert to 1-indexed
        
        print(f"{node_idx}     [{row[0]:6d}, {row[1]:6d}, {row[2]:6d}]    {result}")
        
        results.append(result)
    
    return np.array(results, dtype=np.int32)

def compare_with_gold(computed, gold, label="Standard Argmax"):
    """Compare computed results with gold output"""
    print("\n" + "="*60)
    print(f"COMPARISON: {label} vs Gold Output")
    print("="*60)
    
    print("\nNode  Computed  Gold  Status")
    print("-" * 35)
    
    matches = 0
    for i in range(len(computed)):
        status = "✓ PASS" if computed[i] == gold[i] else "✗ FAIL"
        if computed[i] == gold[i]:
            matches += 1
        print(f"{i}       {computed[i]}        {gold[i]}    {status}")
    
    print("-" * 35)
    print(f"Total: {matches}/{len(computed)} tests passed")
    
    return matches == len(computed)

def main():
    print("="*60)
    print("GCN Computation Verification Script")
    print("="*60)
    
    # Read input data
    print("\nReading input data files...")
    try:
        features = read_feature_data('Data/feature_data.txt')
        weights = read_weight_data('Data/weight_data.txt')
        coo = read_coo_data('Data/coo_data.txt')
        gold = read_gold_output('Data/gold_address.txt')
        print("✓ All data files loaded successfully")
    except FileNotFoundError as e:
        print(f"✗ Error: {e}")
        print("\nMake sure data files are in the 'Data' directory:")
        print("  - Data/feature_data.txt")
        print("  - Data/weight_data.txt")
        print("  - Data/coo_data.txt")
        print("  - Data/gold_address.txt")
        return
    
    # Step 1: Transformation
    fm_wm = compute_transformation(features, weights)
    
    # Step 2: Combination
    adj_fm_wm = compute_combination(fm_wm, coo)
    
    # Step 3: Argmax (try different methods)
    print("\n" + "="*60)
    print("TRYING DIFFERENT ARGMAX INTERPRETATIONS")
    print("="*60)
    
    # Method 1: Standard argmax (0-indexed)
    argmax_standard = compute_argmax(adj_fm_wm)
    compare_with_gold(argmax_standard, gold, "Standard Argmax (0-indexed)")
    
    # Method 2: Highest non-zero column index
    argmax_nonzero = compute_argmax_highest_nonzero(adj_fm_wm)
    compare_with_gold(argmax_nonzero, gold, "Highest Non-Zero Column")
    
    # Method 3: 1-indexed argmax
    argmax_1indexed = compute_argmax_1indexed(adj_fm_wm)
    compare_with_gold(argmax_1indexed, gold, "1-Indexed Argmax")
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print("\nGold output expects:")
    print(f"{gold}")
    print("\nIf no method matches perfectly, the gold file or")
    print("interpretation may need clarification.")

if __name__ == "__main__":
    main()