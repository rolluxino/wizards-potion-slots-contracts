// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
contract RolluxinoSlotGameLogic {
    constructor() {
        owner = msg.sender;
    }
    struct WinningLine {
        uint8 lineId;
        uint256 normalizedPayout;
        uint8[5] positions;
    }
    address public immutable owner;
    function getRegularWinningLines(
        uint8[5][13] memory lineDefinitions,
        uint64[3] memory paytable,
        uint8[3][5] memory symbols
    ) public pure returns (WinningLine[] memory, uint256) {
        WinningLine[] memory winningLines = new WinningLine[](13); 
        uint8 count;
        uint256 totalNormalizedWinAmount;
        for (uint8 i; i < 13; ) {
            uint8[5] memory symbolsLine = getSymbolsForDefinition(
                symbols,
                lineDefinitions[i]
            );
            WinningLine memory winningLine = matchLeftToRight(
                symbolsLine,
                paytable,
                lineDefinitions,
                i
            );
            if (winningLine.lineId != 255) {
                winningLines[count] = winningLine;
                totalNormalizedWinAmount += winningLine.normalizedPayout;
                count++;
            }
            unchecked {
                ++i;
            } 
        }
        assembly {
            mstore(winningLines, count)
        }
        return (winningLines, totalNormalizedWinAmount);
    }
    function matchLeftToRight(
        uint8[5] memory symbols,
        uint64[3] memory paytable,
        uint8[5][13] memory lineDefinitions,
        uint8 lineId
    ) public pure returns (WinningLine memory) {
        uint8[5][3] memory linePatterns = [
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 0],
            [1, 1, 1, 0, 0]
        ]; 
        uint8 firstValidSymbol = 6; 
        for (uint8 i; i < 5; ) {
            if (symbols[i] != 6) {
                firstValidSymbol = symbols[i];
                break;
            }
            unchecked {
                ++i;
            } 
        }
        for (uint8 i; i < 3; ) {
            bool isMatch = true;
            for (uint8 j; j < 5; ) {
                if (linePatterns[i][j] == 1) {
                    if (
                        symbols[j] == 7 ||
                        (symbols[j] != 6 && 
                            symbols[j] != firstValidSymbol)
                    ) {
                        isMatch = false;
                        break;
                    }
                }
                unchecked {
                    ++j;
                } 
            }
            if (isMatch) {
                uint8[5] memory position = convertMatchToPosition(
                    linePatterns[i],
                    lineDefinitions[lineId]
                );
                return WinningLine(lineId, paytable[i], position);
            }
            unchecked {
                ++i;
            } 
        }
        return WinningLine(255, 0, [255, 255, 255, 255, 255]);
    }
    function convertMatchToPosition(
        uint8[5] memory linePattern,
        uint8[5] memory lineDefinition
    ) public pure returns (uint8[5] memory result) {
        for (uint8 i; i < 5; ) {
            if (linePattern[i] == 1) {
                result[i] = lineDefinition[i];
            } else {
                result[i] = 255;
            }
            unchecked {
                ++i;
            } 
        }
        return result;
    }
    function getSymbolsForDefinition(
        uint8[3][5] memory symbols,
        uint8[5] memory definition
    ) public pure returns (uint8[5] memory) {
        uint8[5] memory symbolsLine;
        for (uint8 i; i < 5; ) {
            for (uint8 j; j < 3; ) {
                if (definition[i] == j) {
                    symbolsLine[i] = symbols[i][j];
                    break;
                }
                unchecked {
                    ++j;
                } 
            }
            unchecked {
                ++i;
            } 
        }
        return symbolsLine;
    }
    function calculateOutcome(
        string memory seed,
        uint16 seedPosition,
        bool isBonusMode
    ) public pure returns (uint16, uint256, uint8) {
        (uint16 newSeedPosition, uint8[3][5] memory symbols) = getRandomSymbols(
            seed,
            seedPosition,
            isBonusMode
        );
        uint8[5][13] memory lineDefinitions = [
            [1, 1, 1, 1, 1],
            [0, 0, 0, 0, 0],
            [2, 2, 2, 2, 2],
            [0, 1, 2, 1, 0],
            [2, 1, 0, 1, 2],
            [0, 0, 1, 0, 0],
            [2, 2, 1, 2, 2],
            [1, 1, 0, 1, 1],
            [1, 1, 2, 1, 1],
            [0, 1, 1, 1, 0],
            [2, 1, 1, 1, 2],
            [0, 1, 0, 1, 0],
            [2, 1, 2, 1, 2]
        ]; 
        WinningLine[] memory winningLines;
        uint256 normalizedWinAmount;
        uint64[3] memory paytable = [7 ether, 0.80 ether, 0.10 ether]; 
        if (!isBonusMode) {
            (winningLines, normalizedWinAmount) = getRegularWinningLines(
                lineDefinitions,
                paytable,
                symbols
            );
        } else {
            (winningLines, normalizedWinAmount) = getBonusWinningLines(
                lineDefinitions,
                paytable,
                symbols
            );
        }
        uint8 bonusGamesCount;
        if (!isBonusMode) {
            bonusGamesCount = getBonusGamesCount(symbols);
        }
        return (newSeedPosition, normalizedWinAmount, bonusGamesCount);
    }
    function getBonusWinningLines(
        uint8[5][13] memory lineDefinitions,
        uint64[3] memory paytable,
        uint8[3][5] memory symbols
    ) public pure returns (WinningLine[] memory, uint256) {
        WinningLine[] memory scatterWinningLines = new WinningLine[](13); 
        uint256 totalWin = 0;
        for (uint8 i = 0; i < 13; ) {
            uint8[5] memory symbolsLine = getSymbolsForDefinition(
                symbols,
                lineDefinitions[i]
            );
            (
                uint8 mostFrequentSymbol,
                uint8 matchingSymbolCount
            ) = findMostFrequentSymbol(symbolsLine);
            if (matchingSymbolCount >= 3) {
                uint8[5] memory position = positionScatteredWinningLine(
                    mostFrequentSymbol,
                    symbolsLine,
                    lineDefinitions[i]
                );
                uint256 winAmount = paytable[5 - matchingSymbolCount] * 2;
                totalWin += winAmount;
                scatterWinningLines[i] = WinningLine(i, winAmount, position);
            }
            unchecked {
                ++i;
            } 
        }
        return (scatterWinningLines, totalWin);
    }
    function findMostFrequentSymbol(
        uint8[5] memory symbols
    ) internal pure returns (uint8 symbol, uint8 count) {
        count;
        symbol = 6; 
        uint8 wildCount;
        uint8[] memory symbolFrequency = new uint8[](10);
        for (uint8 i = 0; i < 5; i++) {
            if (symbols[i] != 6) {
                symbolFrequency[symbols[i]]++;
                if (symbolFrequency[symbols[i]] > count) {
                    count = symbolFrequency[symbols[i]];
                    symbol = symbols[i];
                }
            } else {
                wildCount += 1;
            }
        }
        count += wildCount;
        return (symbol, count);
    }
    function positionScatteredWinningLine(
        uint256 mostFrequentSymbol,
        uint8[5] memory symbolLine,
        uint8[5] memory lineDefinition
    ) internal pure returns (uint8[5] memory) {
        uint8[5] memory result;
        for (uint8 i = 0; i < symbolLine.length; i++) {
            if (symbolLine[i] == mostFrequentSymbol || symbolLine[i] == 6) {
                result[i] = lineDefinition[i];
            } else {
                result[i] = 255;
            }
        }
        return result;
    }
    function getBonusGamesCount(
        uint8[3][5] memory symbols
    ) public pure returns (uint8) {
        uint8 bonusPositionCount;
        for (uint8 i; i < 5; ) {
            for (uint8 j; j < 3; ) {
                if (symbols[i][j] == 7) {
                    bonusPositionCount += 1; 
                    break;
                }
                unchecked {
                    ++j;
                } 
            }
            unchecked {
                ++i;
            } 
        }
        uint8 bonusSpinsCount;
        if (bonusPositionCount > 2) {
            if (bonusPositionCount == 3) {
                bonusSpinsCount = 1;
            } else if (bonusPositionCount == 4) {
                bonusSpinsCount = 3;
            } else if (bonusPositionCount == 5) {
                bonusSpinsCount = 6;
            }
        }
        return bonusSpinsCount;
    }
    function getSeedPayout(
        string memory seed,
        uint16 position,
        uint8 prevBonusSpinsCount,
        uint256 betSize
    ) public pure returns (uint256, uint16, uint8) {
        (
            uint16 newSeedPosition,
            uint256 normalizedWinAmount,
            uint8 newBonusSpinsCount
        ) = calculateOutcome(seed, position, prevBonusSpinsCount > 0);
        if (prevBonusSpinsCount > 0) {
            prevBonusSpinsCount -= 1;
        } else if (newBonusSpinsCount > 0) {
            prevBonusSpinsCount = newBonusSpinsCount;
        }
        uint256 totalPayout = normalizedWinAmount * (betSize / 1 ether);
        return (totalPayout, newSeedPosition, prevBonusSpinsCount);
    }
    function getRandomSymbols(
        string memory seed,
        uint16 seedPosition,
        bool isBonusMode
    ) public pure returns (uint16, uint8[3][5] memory) {
        uint8[3][5] memory symbolsByReel;
        for (uint8 reel; reel < 5; ) {
            uint8[3] memory symbols;
            bool hasBonusSymbol;
            for (uint8 i; i < 3; ) {
                uint8 symbolPosition = extractDigit(seed, seedPosition);
                seedPosition++;
                if (!isBonusMode && symbolPosition == 7) {
                    if (hasBonusSymbol) {
                        do {
                            symbolPosition = extractDigit(
                                seed,
                                seedPosition
                            );
                            seedPosition++;
                        } while (symbolPosition == 7); 
                    } else {
                        hasBonusSymbol = true;
                    }
                } else if (symbolPosition == 6) {
                    uint8 nextSymbolPosition = extractDigit(
                        seed,
                        seedPosition
                    );
                    seedPosition++;
                    if (nextSymbolPosition == 7 || nextSymbolPosition <= 3) {
                        if (!hasBonusSymbol) {
                            symbolPosition = 7; 
                            hasBonusSymbol = true;
                        } else {
                            if (nextSymbolPosition <= 3) {
                                symbolPosition = nextSymbolPosition;
                            }
                        }
                    }
                }
                symbols[i] = symbolPosition;
                unchecked {
                    ++i;
                } 
            }
            symbolsByReel[reel] = symbols;
            unchecked {
                ++reel;
            } 
        }
        return (seedPosition, symbolsByReel);
    }
    function extractDigit(
        string memory seed,
        uint16 position
    ) public pure returns (uint8) {
        require(position < bytes(seed).length, "Position out of range");
        uint8 digit = uint8(bytes(seed)[position]) - uint8(bytes1("0"));
        return digit;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }
}
