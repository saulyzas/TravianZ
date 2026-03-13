-- ----------------------------------------------------------------------------------------
-- oasis regeneration script
-- used during installation, server reset, oasis reset & automation (nature repopulation)
-- 
-- original author: martinambrus
-- revised and improved: haki99
-- ----------------------------------------------------------------------------------------


-- Nature regeneration time.
-- 
-- type:        int
-- description: when > -1, used to update the last oasis reset time (Automation nature regeneration)
--               when == -1, used to reset oasis data into original state (conquered > unoccupied)

SET @natureRegTime = %NATURE_REG_TIME%;



-- A temporary table with oasis village ID(s).
-- Used instead of variable so we can work with it as with array.
-- The only other option would be to repeat IDs replacements below
-- or define them once in a string and use FIND_IN_SET() for lookups,
-- which is TERRIBLE, performance-wise (since it doesn't use indexes).

CREATE TEMPORARY TABLE %PREFIX%oids (id INT NOT NULL, PRIMARY KEY (id));
INSERT INTO %PREFIX%oids VALUES %VILLAGEID%;



-- Equivalent to "VILLAGEID === -1" (in PHP). Determines whether we have
-- any single oasis to actually update (mode = conquered > unocupied)
-- or we're updating 1 or more specific oasis (mode = install, server reset, Automation's nature regen).
 
SET @noVillage = ((SELECT id FROM %PREFIX%oids LIMIT 1) = -1);

-- Get the number of players
SELECT COUNT(*) INTO @playerCount FROM %PREFIX%users WHERE id > 6;

-- Calculate average progression for all real players (owner > 6) from culture points (CP) and population of villages (pop)
SELECT IFNULL(AVG(pop + cp), 0) INTO @avgPlayerProgress FROM %PREFIX%vdata WHERE owner > 6;

-- ----------------------------------------------------------------
-- Calculate growth factor based on player progression
-- Scale between 0.3 and 3.0
-- ----------------------------------------------------------------
SET @growthFactor = LEAST(3.0, GREATEST(0.3, @avgPlayerProgress / 1000));

-- faster access to first oasis ID, so we don't need to reselect all the time below 
SET @firstVillage = (SELECT id FROM %PREFIX%oids LIMIT 1);

-- minimum and maximum number of units for oasis with "high" field set to 0
SET @minUnitsForOasis0 = GREATEST(5, FLOOR(5 * @growthFactor));
SET @maxUnitsForOasis0 = LEAST(FLOOR(@minUnitsForOasis0 + 5  + (@playerCount * 1.5) * @growthFactor), 30);

-- minimum and maximum number of units for oasis with "high" field set to 1
SET @minUnitsForOasis1 = GREATEST(10, FLOOR(10 * @growthFactor));
SET @maxUnitsForOasis1 = LEAST(FLOOR(@minUnitsForOasis1 + 10 + (@playerCount * 2) * @growthFactor), 60);

-- minimum and maximum number of units for oasis with "high" field set to 2
SET @minUnitsForOasis2 = GREATEST(20, FLOOR(20 * @growthFactor));
SET @maxUnitsForOasis2 = LEAST(FLOOR(@minUnitsForOasis2 + 15 + (@playerCount * 3) * @growthFactor), 90);

-- Setting a maximum for every type of Oasis so large servers won't turn oasis into fortresses
SET @maxUnitsForOasis0 = LEAST(@maxUnitsForOasis0, 30);
SET @maxUnitsForOasis1 = LEAST(@maxUnitsForOasis1, 60);
SET @maxUnitsForOasis2 = LEAST(@maxUnitsForOasis2, 90);

-- ----------------------------------------
-- reset oasis data (conquered > unoccupied)
-- ------------------------------------------
UPDATE %PREFIX%odata
    SET
        conqured = 0,
        wood = 800,
        iron = 800,
        clay = 800,
        maxstore = 800,
        crop = 800,
        maxcrop = 800,
        lastupdated = UNIX_TIMESTAMP(),
        lastupdated2 = UNIX_TIMESTAMP(),
        loyalty=100,
        owner=2,
        name='Unoccupied Oasis'
    WHERE
        @natureRegTime = -1
        AND
        conqured = @firstVillage;

-- ---------------------------------------------
-- remove past reports (conquered > unoccupied)
-- ---------------------------------------------
DELETE FROM %PREFIX%ndata
    WHERE
        @natureRegTime = -1
        AND
        toWref = @firstVillage;


-- ----------------------------------------------------------------
-- update next regeneration time (Automation, nature regeneration)
-- ----------------------------------------------------------------
UPDATE
    %PREFIX%odata
SET
    lastupdated2 = UNIX_TIMESTAMP() + @natureRegTime
WHERE
    @natureRegTime > -1
    AND
    wref IN ( SELECT id FROM %PREFIX%oids );


-- -----------------------------------------------------------------------
-- update number of units depending on the oasis type                  --
-- the more lucrative the oasis is, the better defense will it get :-P --
-- -----------------------------------------------------------------------


-- +25% lumber oasis (Type 1, 2)
UPDATE %PREFIX%units u
JOIN %PREFIX%odata o ON u.vref = o.wref
SET
    u.u35 = LEAST(u.u35 + FLOOR((5 + RAND() * 10) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u36 = LEAST(u.u36 + FLOOR((0 + RAND() * 5) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u37 = LEAST(u.u37 + FLOOR((0 + RAND() * 5) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END)
WHERE
(
    (@firstVillage = -1 AND u.vref IN (SELECT id FROM %PREFIX%wdata WHERE oasistype IN (1,2)))
    OR
    (@firstVillage > -1 AND u.vref IN (SELECT id FROM %PREFIX%oids))
);

-- +25% lumber and +25% crop oasis (Type 3)
UPDATE %PREFIX%units u
JOIN %PREFIX%odata o ON u.vref = o.wref
SET
    u.u35 = LEAST(u.u35 + FLOOR((5 + RAND() * 15) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u36 = LEAST(u.u36 + FLOOR((0 + RAND() * 5) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u37 = LEAST(u.u37 + FLOOR((0 + RAND() * 5) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u38 = LEAST(u.u38 + FLOOR((0 + RAND() * 5) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u40 = LEAST(u.u40 + FLOOR((0 + RAND() * 3) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END)
WHERE
(
    (@firstVillage = -1 AND u.vref IN (SELECT id FROM %PREFIX%wdata WHERE oasistype = 3))
    OR
    (@firstVillage > -1 AND u.vref IN (SELECT id FROM %PREFIX%oids))
);

-- +25% clay oasis (Type 4) -- Atskirta nuo 5 tipo
UPDATE %PREFIX%units u
JOIN %PREFIX%odata o ON u.vref = o.wref
SET
    u.u31 = LEAST(u.u31 + FLOOR((10 + RAND() * 15) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u32 = LEAST(u.u32 + FLOOR((5 + RAND() * 15) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END),
    u.u35 = LEAST(u.u35 + FLOOR((0 + RAND() * 10) * @growthFactor),
        CASE o.high
            WHEN 0 THEN FLOOR(@minUnitsForOasis0 + RAND() * (@maxUnitsForOasis0 - @minUnitsForOasis0))
            WHEN 1 THEN FLOOR(@minUnitsForOasis1 + RAND() * (@maxUnitsForOasis1 - @minUnitsForOasis1))
            WHEN 2 THEN FLOOR(@minUnitsForOasis2 + RAND() * (@maxUnitsForOasis2 - @minUnitsForOasis2))
        END)
WHERE
(
    (@firstVillage = -1 AND u.vref IN (SELECT id FROM %PREFIX%wdata WHERE oasistype = 4))
    OR
    (@firstVillage > -1 AND u.vref IN (SELECT id FROM %PREFIX%oids))
);

-- ---------------------------------------------------------------------------------------------------
-- CUSTOM UPDATE: Oases types 5 to 12
-- Logic: Fills with weak animals (Type 1-3: u31, u32, u33) with counts between 5 and 12.
-- This applies to: +25% Clay(5), Clay+Crop(6), Iron(7,8), Iron+Crop(9), Crop(10,11), 50%Crop(12).
-- ---------------------------------------------------------------------------------------------------
UPDATE %PREFIX%units u
JOIN %PREFIX%odata o ON u.vref = o.wref
SET
    u.u31 = FLOOR(5 + RAND() * 8), -- Random 5-12 rats
    u.u32 = FLOOR(5 + RAND() * 8), -- Random 5-12 spiders
    u.u33 = FLOOR(5 + RAND() * 8)  -- Random 5-12 snakes
WHERE
(
    (@firstVillage = -1 AND u.vref IN (SELECT id FROM %PREFIX%wdata WHERE oasistype IN (5, 6, 7, 8, 9, 10, 11, 12)))
    OR
    (@firstVillage > -1 AND u.vref IN (SELECT id FROM %PREFIX%oids))
);
