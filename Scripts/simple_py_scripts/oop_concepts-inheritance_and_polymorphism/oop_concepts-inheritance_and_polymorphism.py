class Animal:
    """Base class demonstrating inheritance and polymorphism."""
    
    def speak(self) -> str:
        """Returns a generic animal sound."""
        return "Sound"

class Dog(Animal):
    """Dog class inheriting from Animal and overriding speak method."""
    
    def speak(self) -> str:
        """Returns a dog-specific sound."""
        return "Bark"

def demonstrate_polymorphism() -> None:
    """Demonstrates polymorphism with inherited classes."""
    animal = Animal()
    dog = Dog()
    print(animal.speak())  # Output: Sound
    print(dog.speak())      # Output: Bark

demonstrate_polymorphism()
