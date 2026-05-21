#include <iostream>

int
main()
{
    int* array = new int[5]{10, 20, 30, 40, 50};
    delete[] array;

    std::cout << "Value at index 2: " << array[2] << std::endl;

    return 0;
}
