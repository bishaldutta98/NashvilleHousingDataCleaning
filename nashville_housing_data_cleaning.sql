-- CLEANING DATA USING SQL QUERY
SELECT*
FROM [Portfolio Project].dbo.NashvilleHousing

-- Standardising the Date format (eliminating the time constraints from the SaleDate)
SELECT SaleDate, CONVERT(DATE, SaleDate)
FROM [Portfolio Project].dbo.NashvilleHousing

UPDATE NashvilleHousing
SET SaleDate = CONVERT(DATE, SaleDate) --This code is not working for some reason, so we will try an alternative method.

ALTER TABLE NashvilleHousing
ADD SaleDateConverted DATE;

UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate)



-- Populate the NULL PropertyAddress
SELECT PropertyAddress
FROM [Portfolio Project].dbo.NashvilleHousing
WHERE PropertyAddress IS NULL;				-- So we can see that there are 29 NULL values and we have to populate these values

-- NOTE: If we look at the data, we can see that the rows with similar ParcelID has same PropertyAddress
-- So, I can use this relation to populate the NULL values. For this, we have to do a SELF JOIN of the table.

SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM [Portfolio Project].dbo.NashvilleHousing a				--ISNULL(where we want to look for NULL value, what we want to populate the NULL value with)
JOIN [Portfolio Project].dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;		
-- the ISNULL has populated the NULL cells with the addresses where the ParcelID is common.
-- So, I can use this to insert a new column and update the table.

UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM [Portfolio Project].dbo.NashvilleHousing a				
JOIN [Portfolio Project].dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;	 -- now if I run the previous query, it shows no result as there is no NULL data left.



-- BREAKING OUT ADDRESS INTO INDIVIDUAL COLUMNS
SELECT PropertyAddress
FROM [Portfolio Project].dbo.NashvilleHousing -- here we can see that PropertyAddress has the address and the city seperated by ,(delimiter)

SELECT 
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) AS Address, --SUBSTRING extracts some characters from a string
--SUBSTRING(where we want to extract from, where we want to start, the length- CHARINDEX('what we want to search by', where?)
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress) ) AS City
-- Here, the syntax is same just the starting position is +1 after the delimiter, LEN(PropertyAddress) - we just put the length of the PropertyAddress
FROM [Portfolio Project].dbo.NashvilleHousing

--Now, I need to update these into new columns
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress nvarchar(255);

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1)


ALTER TABLE NashvilleHousing
ADD PropertySplitCity nvarchar(255);

UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress) )

-- Now we can see the two columns in the updated table
SELECT*
FROM [Portfolio Project].dbo.NashvilleHousing


-- Now, I have to do the same thing for OwnerAddress, but it has two delimiters and the above process will become very complicated.
--I have to seperate the address, city and state. This time we will use the PARSENAME query which is very useful for delimited values.
-- NOTE: PARSENAME can only detect 'periods' and not commas. So, we have to convert the ',' into '.'.
SELECT
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),		--PARSENAME works backwards, so we write 3,2,1 instead of 1,2,3.
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM [Portfolio Project].dbo.NashvilleHousing

-- Now I need to update these into three new columns for cleaning it.
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)


ALTER TABLE NashvilleHousing
ADD OwnerSplitCity nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)


ALTER TABLE NashvilleHousing
ADD OwnerSplitState nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)

-- Now, if we see the updated table, there should be three new columns
SELECT*
FROM [Portfolio Project].dbo.NashvilleHousing



--CONVERTING THE Y AND N TO 'YES' OR 'NO' (le's look at the SoldAsVacant column)
SELECT DISTINCT(SoldAsVacant)
FROM [Portfolio Project].dbo.NashvilleHousing -- I can see that there are 4 distinct values - N, Yes, Y, No (But we want only yes or no values)

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM [Portfolio Project].dbo.NashvilleHousing 
GROUP BY SoldAsVacant
ORDER BY 2	--There are 399 N values and 52 Y values, which is huge.

--Now I will change these values. I will use a case statement
SELECT SoldAsVacant,
CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant 
	END
FROM [Portfolio Project].dbo.NashvilleHousing -- We see that the Y and N are changed to Yes and No respectively.

-- Now, we need to update this into the table.
UPDATE NashvilleHousing
SET SoldAsVacant = CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant 
	END

-- Now if we run the SELECT DISTINCT query again, we get only two values- Yes and No
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM [Portfolio Project].dbo.NashvilleHousing 
GROUP BY SoldAsVacant
ORDER BY 2	-- we get only two values- Yes and No



-- REMOVING DUPLICATE VALUES
-- I am going to use CTE and some windows functions to perform this task
WITH RowNumCTE AS(
SELECT*,
	ROW_NUMBER() OVER (										-- This is a Windows function
	PARTITION BY ParcelID,										
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

FROM [Portfolio Project].dbo.NashvilleHousing 
--ORDER BY ParcelID					(ORDER BY cannot be used in a CTE)
)
SELECT*
FROM RowNumCTE
WHERE row_num >1
ORDER BY PropertyAddress
-- It can be seen that there are 104 duplicate values.

--Now I have to delete these duplicate values.

WITH RowNumCTE AS(
SELECT*,
	ROW_NUMBER() OVER 	--ROW_NUMBER:More specifically, returns the sequential number of a row within a partition of a result set, starting at 1 for the first row in each partition.			
	(PARTITION BY ParcelID,									-- This is a Windows function(PARTITION BY)	
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

FROM [Portfolio Project].dbo.NashvilleHousing 
--ORDER BY ParcelID					(ORDER BY cannot be used in a CTE)
)
DELETE
FROM RowNumCTE
WHERE row_num >1
--Now if I run the previous query again, it doesn't show any duplicate values.



--DELETING UNUSED COLUMNS
SELECT*
FROM [Portfolio Project].dbo.NashvilleHousing 

/* Now, if we look at the data in the table, the PropertyAddress and the OwnerAddress are not useful to us anymore because we have already split them into individual
columns, also the TaxDistrict is not useful for any of our purpose. So, I can now delete these columns. In practice, we must not delete columns from the raw data,
but this is useful when we are saving views for later use.*/

ALTER TABLE  [Portfolio Project].dbo.NashvilleHousing 
DROP COLUMN  PropertyAddress, OwnerAddress, TaxDistrict

-- Now when we load the table, the columns that we dropped are not loaded, i.e, they are deleted.
SELECT*
FROM [Portfolio Project].dbo.NashvilleHousing 

-- the saledate column is also not needed as there is another column 'SaleDateConverted'.
ALTER TABLE NashvilleHousing 
DROP COLUMN SaleDate