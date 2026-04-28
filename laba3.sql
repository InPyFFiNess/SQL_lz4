--ЗАДАНИЕ 1

create database SalesDB

use SalesDB

CREATE TABLE Customers(
	CustomerID INT IDENTITY (1,1) PRIMARY KEY,
	FullName NVARCHAR(100) NOT NULL,
	Email NVARCHAR(100) UNIQUE NOT NULL,
	RegistrationDate DATETIME DEFAULT GETDATE() NOT NULL,
)

CREATE TABLE Orders(
	OrderID INT IDENTITY (1,1) PRIMARY KEY,
	CustomerID INT NOT NULL,
	OrderTotal FLOAT CHECK (OrderTotal > 0) NOT NULL,
	OrderDate DATETIME DEFAULT GETDATE() NOT NULL,
	[Status] NVARCHAR(20) DEFAULT 'Новый' NOT NULL,
	CONSTRAINT FK_1 FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
)

create database LogisticsDB

use LogisticsDB

CREATE TABLE Warehouses(
	WarehousesID INT IDENTITY (1,1) PRIMARY KEY,
	[Location] NVARCHAR(100) UNIQUE  NOT NULL,
	Capacity FLOAT  NOT NULL,
	ManagerContact NVARCHAR(50) DEFAULT 'Не назначен' NOT NULL,
	CreateDate DATETIME DEFAULT GETDATE() NOT NULL,
)

CREATE TABLE Shipments(
	ShipmentID INT IDENTITY (1,1) PRIMARY KEY,
	WarehousesID INT NOT NULL,
	OrderID INT NOT NULL,
	TrackingCode NVARCHAR(50) UNIQUE NOT NULL,
	[Weight] FLOAT NOT NULL,
	DispatchDate DATETIME,
	[Status] NVARCHAR(20) DEFAULT 'Ожидает отправки' NOT NULL,
	CONSTRAINT FK_2 FOREIGN KEY (WarehousesID) REFERENCES  Warehouses(WarehousesID),
)

GO

CREATE TRIGGER trg_ShipmentsCheckOrder
ON Shipments
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        LEFT JOIN SalesDB.dbo.Orders o ON i.OrderID = o.OrderID
        WHERE o.OrderID IS NULL
    )
    BEGIN
        RAISERROR ('Ошибка: Указанный OrderID не существует в SalesDB.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

--ЗАДАНИЕ 2

use SalesDB

GO
CREATE FUNCTION dbo.fn_GetCustomers()
RETURNS TABLE
AS
RETURN 
(
    SELECT CustomerID, FullName, Email, RegistrationDate
    FROM dbo.Customers
);
GO

GO
CREATE FUNCTION dbo.fn_GetOrdersByStatus(@status NVARCHAR(20))
RETURNS TABLE
AS
RETURN 
(
    SELECT OrderID, CustomerID, OrderTotal, OrderDate, [Status]
    FROM dbo.Orders
    WHERE [Status] = @status
);
GO

USE LogisticsDB;

GO
CREATE FUNCTION dbo.fn_GetShipmentsByWarehouse(@wid INT)
RETURNS TABLE
AS
RETURN 
(
    SELECT ShipmentID, WarehousesID, OrderID, TrackingCode, [Weight], DispatchDate, [STATUS]
    FROM dbo.Shipments
    WHERE WarehousesID = @wid
);
GO

SELECT * FROM SalesDB.dbo.fn_GetCustomers();
SELECT * FROM SalesDB.dbo.fn_GetOrdersByStatus('НОВЫЙ');
SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1); 
SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(2); 



--ЗАДАНИЕ 3
use SalesDB

CREATE TRIGGER trg_AddToShipments
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
	BEGIN TRANSACTION
		BEGIN TRY
			INSERT INTO LogisticsDB.dbo.Shipments(WarehouseID, OrderID, TrackingCode, DispatchDate, [Weight], [Status])
				SELECT 1, OrderID,'TRK_' + CONVERT(NVARCHAR(46), NEWID()), NULL, 1, 'Ожидает отправки' FROM inserted
				WHERE inserted.[Status] = 'Подтверждён'
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			THROW
		END CATCH
END

--ЗАДАНИЕ 4

use SalesDB

GO
CREATE PROCEDURE sp_AddCustomer
    @Name NVARCHAR(100),
    @Email NVARCHAR(100)
AS
BEGIN
    INSERT INTO Customers (FullName, Email)
    VALUES (@Name, @Email);
END;
GO

GO
CREATE PROCEDURE sp_AddOrder
    @CustID INT,
    @Total FLOAT
AS
BEGIN
    INSERT INTO Orders (CustomerID, OrderTotal)
    VALUES (@CustID, @Total);
END;
GO

INSERT INTO LogisticsDB.dbo.Warehouses ([Location], Capacity) VALUES ('Склад 1', 5000);

EXEC sp_AddCustomer @Name = 'Владик Слуцкий', @Email = 'vladik@mail.ru';
EXEC sp_AddOrder @CustID = 1, @Total = 500.0;

UPDATE SalesDB.dbo.Orders SET [Status] = 'Подтверждён' WHERE OrderID = 1;

SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1);

BEGIN TRY
    EXEC sp_AddOrder @CustID = 1, @Total = -100; 
END TRY
BEGIN CATCH
    PRINT 'Сумма заказа не может быть отрицательной';
END CATCH;

BEGIN TRY
    EXEC sp_AddCustomer @Name = 'Клон', @Email = 'vladik@mail.ru'; 
END TRY
BEGIN CATCH
    PRINT 'Такой Email уже есть в базе';
END CATCH;

SELECT * FROM SalesDB.dbo.fn_GetCustomers();
SELECT * FROM SalesDB.dbo.fn_GetOrdersByStatus('Подтверждён');	
SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1);

BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE SalesDB.dbo.Orders 
        SET OrderTotal = OrderTotal / 0 
        WHERE OrderID = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Произошла критическая ошибка. Все изменения отменены!';
END CATCH;
