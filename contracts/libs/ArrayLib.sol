// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library ArrayLib {
    function countMatch(bytes memory first, bytes6 second)
        internal
        pure
        returns (uint8)
    {
        uint8 matchedCount = 0;
        // Simply get (start from) the first number from the input array
        for (uint8 ii = 0; ii < first.length; ii++) {
            // and check it against the second array numbers, from first to fourth,
            for (uint8 jj = 0; jj < second.length; jj++) {
                // If you find it
                if (first[ii] == second[jj]) {
                    matchedCount += 1;
                    break;
                }
            }
        }

        return matchedCount;
    }
}
