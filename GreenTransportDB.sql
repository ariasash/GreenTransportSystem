CREATE DATABASE GreenTransportDB;
Go
USE GreenTransportDB;
GO
-- 2. Tabla para Modelos de Vehículos (Normalización: 1NF y 2NF)
-- Evita repetir Marca y Modelo en cada vehículo.
CREATE TABLE ModelosVehiculo (
ModeloID INT PRIMARY KEY IDENTITY(1,1),
Marca VARCHAR(50) NOT NULL,
Modelo VARCHAR(50) NOT NULL,
TipoElectrico VARCHAR(30) -- Ej: 'Sedán', 'Furgoneta', 'Camión'
);
-- 3. Tabla para Vehículos
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

-- 5 Tabla para Mantenimientos (Entidad de Relación N:M simplificada a 1:N con Vehiculos)
-- Registra cuándo y quién (Conductor) fue responsable de llevar/supervisar el Mantenimiento.
CREATE TABLE Mantenimientos (
MantenimientoID INT PRIMARY KEY IDENTITY(1,1),
VehiculoID INT NOT NULL,
ConductorID INT, -- Quién lo gestionó o lo llevó
FechaInicio DATETIME NOT NULL DEFAULT GETDATE(),
FechaFin DATETIME,
TipoMantenimiento VARCHAR(50) NOT NULL, -- Ej: 'Preventivo', 'Correctivo', 'Inspección'
Costo DECIMAL(10,2) DEFAULT 0.00,
Observaciones NVARCHAR(MAX),
FOREIGN KEY (VehiculoID) REFERENCES Vehiculos(VehiculoID),
FOREIGN KEY (ConductorID) REFERENCES Conductores(ConductorID)
);
-- Insertar Modelos
INSERT INTO ModelosVehiculo (Marca, Modelo, TipoElectrico) VALUES
('Tesla', 'Model 3', 'Sedán'),
('Nissan', 'Leaf', 'Compacto'),
('BYD', 'T3', 'Furgoneta'),
('Volvo', 'FH Electric', 'Camión');

-- Insertar Conductores
INSERT INTO Conductores (Licencia, Nombre, FechaContratacion, Email) VALUES
('C-12345', 'Elena Ramírez', '2022-01-15', 'elena@greentransport.com'),
('C-67890', 'Javier Soto', '2023-05-20', 'javier@greentransport.com');

-- Insertar Vehículos
INSERT INTO Vehiculos (Placa, ModeloID, AnioFabricacion, Kilometraje, EstadoDisponibilidad) VALUES
('GT-A001', 1, 2022, 55000.50, 'Disponible'),
('GT-B002', 2, 2021, 80000.00, 'Disponible'),
('GT-C003', 3, 2023, 12000.75, 'En Mantenimiento'),
('GT-D004', 4, 2024, 500.00, 'Disponible');
-- Insertar Mantenimientos (Simulando 3 mantenimientos históricos)
INSERT INTO Mantenimientos (VehiculoID, ConductorID, FechaInicio, FechaFin, TipoMantenimiento, Costo) VALUES
(1, 1, DATEADD(month, -3, GETDATE()), DATEADD(month, -3, GETDATE()), 'Preventivo', 350.00), -- 3 meses atrás
(2, 2, DATEADD(day, -35, GETDATE()), DATEADD(day, -34, GETDATE()), 'Correctivo', 800.00), -- Más de 1 mes atrás
(3, 1, DATEADD(day, -5, GETDATE()), NULL, 'Inspección', 0.00); -- En curso (Vehículo GT-C003)

--Consulta avanzada con JOIN
--Muestra el nombre del conductor y el detalle de cada mantenimiento que gestionó.
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
--Compara vehículos Disponibles (Activos) versus vehículos En Mantenimiento.
-- Vehículos Activos (Disponibles)
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
LEFT JOIN -- Usamos LEFT JOIN para incluir vehículos que nunca tuvieron mantenimiento
    Mantenimientos M ON V.VehiculoID = M.VehiculoID
GROUP BY
    V.Placa, 
    V.EstadoDisponibilidad, 
    MV.Marca, 
    MV.Modelo -- <--- ¡Esta línea es la corrección clave!
HAVING
    MAX(M.FechaFin) < @FechaLimite OR MAX(M.FechaFin) IS NULL;

	--Implementacion de una Transaccion 
--La transacción garantiza la atomicidad (A de ACID) de la operación: o se registra el mantenimiento y se actualiza el estado del vehículo, o no se hace nada.
-- Parámetros de la nueva operación de Mantenimiento
DECLARE @Vehiculo_a_Mantenimiento INT = 4; -- Vehículo GT-D004
DECLARE @Conductor_Gestor INT = 2; -- Javier Soto
DECLARE @Tipo_Mantenimiento VARCHAR(50) = 'Revisión Inicial';
BEGIN TRANSACTION;
BEGIN TRY
-- 1. Registrar un mantenimiento
INSERT INTO Mantenimientos (VehiculoID, ConductorID, TipoMantenimiento, Observaciones)
VALUES (@Vehiculo_a_Mantenimiento, @Conductor_Gestor, @Tipo_Mantenimiento, 'Vehículo entra a la revisión programada.');
-- 2. Descontar temporalmente la disponibilidad del vehículo (actualizar su estado)
UPDATE Vehiculos
SET EstadoDisponibilidad = 'En Mantenimiento'
WHERE VehiculoID = @Vehiculo_a_Mantenimiento;
-- Si todo lo anterior se ejecuta sin errores, se confirma la transacción.
COMMIT TRANSACTION;
PRINT 'Transacción Exitosa: Mantenimiento registrado y vehículo actualizado.';
END TRY
BEGIN CATCH
-- Si ocurre cualquier error (ej. VehiculoID no existe, violación de clave, etc.), se revierte.
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
PRINT 'Transacción Fallida: Error al registrar el mantenimiento.';
THROW; -- Lanza el error capturado para notificar.
END CATCH;