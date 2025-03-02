import unittest
from unittest.mock import MagicMock

class TestExample(unittest.TestCase):
    """Test class demonstrating the use of unittest and mock."""
    
    def test_add(self) -> None:
        """Tests the mock function for expected return value."""
        mock = MagicMock(return_value=10)
        result = mock()
        self.assertEqual(result, 10)

if __name__ == '__main__':
    unittest.main()
