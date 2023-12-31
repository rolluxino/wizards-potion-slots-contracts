// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
contract RolluxinoStringHelpers {
    function truncateString(
        string memory original,
        uint256 startPosition,
        uint256 endPosition
    ) public pure returns (string memory) {
        require(startPosition <= endPosition, "Start position >= end position");
        require(
            endPosition <= bytes(original).length,
            "End position out of bounds"
        );
        bytes memory originalBytes = bytes(original);
        uint256 length = endPosition - startPosition;
        bytes memory truncatedBytes = new bytes(length);
        for (uint256 i; i < length; i++) {
            truncatedBytes[i] = originalBytes[startPosition + i];
        }
        return string(truncatedBytes);
    }
    function arrayToString(
        uint256[] memory numbers
    ) external pure returns (string memory) {
        string memory result;
        for (uint256 i = 0; i < numbers.length; i++) {
            string memory numberStr = toString(numbers[i]);
            for (uint256 j = 0; j < bytes(numberStr).length; j++) {
                uint8 digit = uint8(bytes(numberStr)[j]) - 48;
                if (digit == 8 || digit == 9) {
                    while (j < bytes(numberStr).length) {
                        j++;
                        if (j < bytes(numberStr).length) {
                            digit = uint8(bytes(numberStr)[j]) - 48;
                            if (digit <= 5) {
                                result = string(
                                    abi.encodePacked(
                                        result,
                                        bytes(numberStr)[j]
                                    )
                                );
                                break;
                            }
                        }
                    }
                } else {
                    result = string(
                        abi.encodePacked(result, bytes(numberStr)[j])
                    );
                }
            }
        }
        return result;
    }
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;   
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
