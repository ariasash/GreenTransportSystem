CREATE DATABASE GreenTransportDB;
Go
USE GreenTransportDB;
GO
-- 2. Tabla para Modelos de Veh�culos (Normalizaci�n: 1NF y 2NF)
-- Evita repetir Marca y Modelo en cada veh�culo.
CREATE TABLE ModelosVehiculo (
ModeloID INT PRIMARY KEY IDENTITY(1,1),
Marca VARCHAR(50) NOT NULL,
Modelo VARCHAR(50) NOT NULL,
TipoElectrico VARCHAR(30) -- Ej: 'Sed�n', 'Furgoneta', 'Cami�n'
);
-- 3. Tabla para Veh�culos
CREATE TABLE Vehiculos (
VehiculoID INT PRIMARY KEY IDENTITY(1,1),
Placa VARCHAR(10) UNIQUE NOT NULL,
ModeloID INT NOT NULL,
AnioFabricacion INT,
Kilometraje DECIMAL(10,2) NOT NULL DEFAULT 0.00,
EstadoDisponibilidad VARCHAR(20) NOT NULL DEFAULT 'Disponible', -- 'Disponible', 'En Mantenimiento', 'Inactivo'
FOREIGN KEY (ModeloID) REFERENCES ModelosVehiculo(ModeloID)
);
-- 4. Tabla para Conductores
CREATE TABLE Conductores (
ConductorID INT PRIMARY KEY IDENTITY(1,1),
Licencia VARCHAR(20) UNIQUE NOT NULL,
Nombre VARCHAR(100) NOT NULL,
FechaContratacion DATE NOT NULL,
Email VARCHAR(100)
);

-- 5 Tabla para Mantenimientos (Entidad de Relaci�n N:M simplificada a 1:N con Vehiculos)
-- Registra cu�ndo y qui�n (Conductor) fue responsable de llevar/supervisar el Mantenimiento.
CREATE TABLE Mantenimientos (
MantenimientoID INT PRIMARY KEY IDENTITY(1,1),
VehiculoID INT NOT NULL,
ConductorID INT, -- Qui�n lo gestion� o lo llev�
FechaInicio DATETIME NOT NULL DEFAULT GETDATE(),
FechaFin DATETIME,
TipoMantenimiento VARCHAR(50) NOT NULL, -- Ej: 'Preventivo', 'Correctivo', 'Inspecci�n'
Costo DECIMAL(10,2) DEFAULT 0.00,
Observaciones NVARCHAR(MAX),
FOREIGN KEY (VehiculoID) REFERENCES Vehiculos(VehiculoID),
FOREIGN KEY (ConductorID) REFERENCES Conductores(ConductorID)
);
-- Insertar Modelos
INSERT INTO ModelosVehiculo (Marca, Modelo, TipoElectrico) VALUES
('Tesla', 'Model 3', 'Sed�n'),
('Nissan', 'Leaf', 'Compacto'),
('BYD', 'T3', 'Furgoneta'),
('Volvo', 'FH Electric', 'Cami�n');

-- Insertar Conductores
INSERT INTO Conductores (Licencia, Nombre, FechaContratacion, Email) VALUES
('C-12345', 'Elena Ram�rez', '2022-01-15', 'elena@greentransport.com'),
('C-67890', 'Javier Soto', '2023-05-20', 'javier@greentransport.com');

-- Insertar Veh�culos
INSERT INTO Vehiculos (Placa, ModeloID, AnioFabricacion, Kilometraje, EstadoDisponibilidad) VALUES
('GT-A001', 1, 2022, 55000.50, 'Disponible'),
('GT-B002', 2, 2021, 80000.00, 'Disponible'),
('GT-C003', 3, 2023, 12000.75, 'En Mantenimiento'),
('GT-D004', 4, 2024, 500.00, 'Disponible');
-- Insertar Mantenimientos (Simulando 3 mantenimientos hist�ricos)
INSERT INTO Mantenimientos (VehiculoID, ConductorID, FechaInicio, FechaFin, TipoMantenimiento, Costo) VALUES
(1, 1, DATEADD(month, -3, GETDATE()), DATEADD(month, -3, GETDATE()), 'Preventivo', 350.00), -- 3 meses atr�s
(2, 2, DATEADD(day, -35, GETDATE()), DATEADD(day, -34, GETDATE()), 'Correctivo', 800.00), -- M�s de 1 mes atr�s
(3, 1, DATEADD(day, -5, GETDATE()), NULL, 'Inspecci�n', 0.00); -- En curso (Veh�culo GT-C003)

--Consulta avanzada con JOIN
--Muestra el nombre del conductor y el detalle de cada mantenimiento que gestion�.
SELECT
C.Nombre AS Conductor,
V.Placa AS Vehiculo,
MV.Marca + ' ' + MV.Modelo AS ModeloVehiculo,
M.TipoMantenimiento,
M.FechaInicio,
M.FechaFin,
M.Costo
FROM
Mantenimientos M
INNER JOIN
Conductores C ON M.ConductorID = C.ConductorID
INNER JOIN
Vehiculos V ON M.VehiculoID = V.VehiculoID
INNER JOIN
ModelosVehiculo MV ON V.ModeloID = MV.ModeloID
ORDER BY
C.Nombre, M.FechaInicio DESC;

--Operacion de conjuntos
--Compara veh�culos Disponibles (Activos) versus veh�culos En Mantenimiento.
-- Veh�culos Activos (Disponibles)
DECLARE @FechaLimite DATE = DATEADD(month, -1, GETDATE());
 SELECT
    V.Placa,
    V.EstadoDisponibilidad,
    MV.Marca + ' ' + MV.Modelo AS Modelo,
    -- Utilizamos CONVERT para asegurar un formato de salida limpio para la fecha
    ISNULL(CONVERT(VARCHAR(25), MAX(M.FechaFin), 120), 'NUNCA') AS UltimaFechaMantenimiento
FROM
    Vehiculos V
INNER JOIN
    ModelosVehiculo MV ON V.ModeloID = MV.ModeloID
LEFT JOIN -- Usamos LEFT JOIN para incluir veh�culos que nunca tuvieron mantenimiento
    Mantenimientos M ON V.VehiculoID = M.VehiculoID
GROUP BY
    V.Placa, 
    V.EstadoDisponibilidad, 
    MV.Marca, 
    MV.Modelo -- <--- �Esta l�nea es la correcci�n clave!
HAVING
    MAX(M.FechaFin) < @FechaLimite OR MAX(M.FechaFin) IS NULL;

	--Implementacion de una Transaccion 
--La transacci�n garantiza la atomicidad (A de ACID) de la operaci�n: o se registra el mantenimiento y se actualiza el estado del veh�culo, o no se hace nada.
-- Par�metros de la nueva operaci�n de Mantenimiento
DECLARE @Vehiculo_a_Mantenimiento INT = 4; -- Veh�culo GT-D004
DECLARE @Conductor_Gestor INT = 2; -- Javier Soto
DECLARE @Tipo_Mantenimiento VARCHAR(50) = 'Revisi�n Inicial';
BEGIN TRANSACTION;
BEGIN TRY
-- 1. Registrar un mantenimiento
INSERT INTO Mantenimientos (VehiculoID, ConductorID, TipoMantenimiento, Observaciones)
VALUES (@Vehiculo_a_Mantenimiento, @Conductor_Gestor, @Tipo_Mantenimiento, 'Veh�culo entra a la revisi�n programada.');
-- 2. Descontar temporalmente la disponibilidad del veh�culo (actualizar su estado)
UPDATE Vehiculos
SET EstadoDisponibilidad = 'En Mantenimiento'
WHERE VehiculoID = @Vehiculo_a_Mantenimiento;
-- Si todo lo anterior se ejecuta sin errores, se confirma la transacci�n.
COMMIT TRANSACTION;
PRINT 'Transacci�n Exitosa: Mantenimiento registrado y veh�culo actualizado.';
END TRY
BEGIN CATCH
-- Si ocurre cualquier error (ej. VehiculoID no existe, violaci�n de clave, etc.), se revierte.
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
PRINT 'Transacci�n Fallida: Error al registrar el mantenimiento.';
THROW; -- Lanza el error capturado para notificar.
END CATCH;