import pandas as pd
import numpy as np

def data_analysis_example() -> None:
    """Demonstrates basic data analysis using pandas and numpy."""
    data = np.array([[1, 2], [3, 4]])
    df = pd.DataFrame(data, columns=['A', 'B'])
    print(df)

data_analysis_example()
