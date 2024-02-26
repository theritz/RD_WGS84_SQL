/****** Procedure that creates a function 'ConvertCoordinatesTable' in schema 'dbo'. 
The function converts RD coordinates ("Rijksdriehoekscoördinaten") in a table to lat-long coordinates.
The input coordinates are fetched by cursor and put in @rdx, @rdy. 
So to get things going you have to adapt this for your situation:

DECLARE cur CURSOR FOR SELECT <identifing_column>, RD_X, RD_Y FROM <table>;

Here columns RD_X and RD_Y contain the X,Y coordinates in the RD coordinate system. 
If these columns are named differently you'll have to refactor more in the code.

******/
CREATE FUNCTION [dbo].[ConvertCoordinatesTable]()
RETURNS @ConvertedCoords TABLE
(
OriginalX FLOAT,
OriginalY FLOAT,
Latitude FLOAT,
Longitude FLOAT
)
AS
BEGIN
    -- Declare constants for the RD coordinate system
    DECLARE @x0 FLOAT = 155000;
    DECLARE @y0 FLOAT = 463000;
    DECLARE @phi0 FLOAT = 52.15517440;
    DECLARE @lam0 FLOAT = 5.38720621;

    -- Declare tables for coefficients
    DECLARE @kpq TABLE (rk INT, k INT, kq INT, val FLOAT);
    INSERT INTO @kpq VALUES (1, 0, 1, 3235.65389), (2, 2, 0, -32.58297), (3, 0, 2, -0.24750), (4, 2, 1, -0.84978), (5, 0, 3, -0.06550), (6, 2, 2, -0.01709), (7, 1, 0, -0.00738), (8, 4, 0, 0.00530), (9, 2, 3, -0.00039), (10, 4, 1, 0.00033), (11, 10, 1, -0.00012);

    DECLARE @lpq TABLE (l INT, lq INT, val FLOAT);
    INSERT INTO @lpq VALUES (1, 0, 5260.52916), (1, 1, 105.94684), (1, 2, 2.45656), (3, 0, -0.81885), (1, 3, 0.05594), (3, 1, -0.05607), (0, 1, 0.01199), (3, 2, -0.00256), (1, 4, 0.00128), (0, 2, 0.00022), (2, 0, -0.00022), (5, 0, 0.00026);

    -- Cursor to iterate through each row in SOMEVIEW
    -- UPDATE THIS LINE to match your situation
    DECLARE cur CURSOR FOR SELECT <identifing_column>, RD_X, RD_Y FROM <table>;

    DECLARE @rdx FLOAT, @rdy FLOAT;

    OPEN cur;
    FETCH NEXT FROM cur INTO @rdx, @rdy;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @dx FLOAT, @dy FLOAT, @phi FLOAT, @lam FLOAT;

        -- Conversion logic here
        SET @dx = 1E-5 * (@rdx - @x0);
        SET @dy = 1E-5 * (@rdy - @y0);

        -- Latitude calculation
        SET @phi = 0;
        DECLARE @k INT = 1;
        WHILE @k <= (SELECT COUNT(*) FROM @kpq)
        BEGIN
            SELECT @phi = @phi + (val * POWER(@dx, k) * POWER(@dy, kq))
            FROM @kpq
            WHERE rk = @k;

            SET @k = @k + 1;
        END;
        SET @phi = @phi0 + @phi / 3600;

        -- Longitude calculation
        SET @lam = 0;
        DECLARE @l INT = 1;
        WHILE @l <= (SELECT COUNT(*) FROM @lpq)
        BEGIN
            SELECT @lam = @lam + (val * POWER(@dx, l) * POWER(@dy, lq))
            FROM @lpq
            WHERE l = @l;

            SET @l = @l + 1;
        END;
        SET @lam = @lam0 + @lam / 3600;

        -- Insert converted coordinates into the table
        INSERT INTO @ConvertedCoords (OriginalX, OriginalY, Latitude, Longitude)
        VALUES (@rdx, @rdy, ROUND(@phi, 5), ROUND(@lam, 5));

        FETCH NEXT FROM cur INTO @rdx, @rdy, @phi, @lam;
    END;

    CLOSE cur;
    DEALLOCATE cur;

    RETURN;
END;

