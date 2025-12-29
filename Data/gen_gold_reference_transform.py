"""
Golden Reference Generator for Transformation Block
Computes Feature Matrix (6x96) × Weight Matrix (96x3) = Result (6x3)
"""

import numpy as np

def read_matrix_file(filename, rows, cols, bits=5):
    """Read binary matrix data from file"""
    matrix = []
    with open(filename, 'r') as f:
        for line in f:
            row = []
            values = line.strip().split()
            for val in values:
                # Convert binary string to integer
                row.append(int(val, 2))
            matrix.append(row)
    return np.array(matrix, dtype=np.uint16)

def main():
    # Read feature matrix (6 rows x 96 columns)
    print("Reading feature matrix...")
    feature_matrix = read_matrix_file('Data/feature_data.txt', 6, 96)
    print(f"Feature matrix shape: {feature_matrix.shape}")
    
    # Read weight matrix (3 rows x 96 columns)
    print("Reading weight matrix...")
    weight_matrix = read_matrix_file('Data/weight_data.txt', 3, 96)
    print(f"Weight matrix shape: {weight_matrix.shape}")
    
    # Compute matrix multiplication: Feature (6x96) × Weight^T (96x3)
    print("\nComputing matrix multiplication...")
    result = np.matmul(feature_matrix, weight_matrix.T)
    print(f"Result matrix shape: {result.shape}")
    
    # Display results
    print("\n" + "="*60)
    print("GOLDEN REFERENCE: Feature × Weight^T")
    print("="*60)
    print("\n         Col0      Col1      Col2")
    print("-" * 40)
    for i in range(6):
        print(f"Row{i}:  {result[i,0]:6d}    {result[i,1]:6d}    {result[i,2]:6d}")
    print("")
    
    # Save to file
    output_file = 'Data/golden_transformation_output.txt'
    print(f"\nSaving golden reference to {output_file}")
    with open(output_file, 'w') as f:
        for i in range(6):
            for j in range(3):
                # Write as 16-bit binary
                f.write(f"{result[i,j]:016b}")
                if j < 2:
                    f.write(" ")
            f.write("\n")
    
    print("Done!")
    
    # Additional statistics
    print("\n" + "="*60)
    print("Statistics:")
    print("="*60)
    print(f"Min value: {np.min(result)}")
    print(f"Max value: {np.max(result)}")
    print(f"Mean value: {np.mean(result):.2f}")
    
    # Check for overflow
    if np.max(result) >= 65536:
        print("\n⚠️  WARNING: Values exceed 16-bit range!")
    else:
        print("\n✓ All values fit within 16-bit range")

if __name__ == "__main__":
    main()