#include <iostream>
#include <limits>

int
main()
{
    int maxInt = std::numeric_limits<int>::max();
    std::cout << "Current max: " << maxInt << std::endl;
    int overflowed = maxInt + 1;
    std::cout << "Overflowed result: " << overflowed << std::endl;
    return 0;
}
