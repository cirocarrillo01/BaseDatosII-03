/* =========================================================
   05_VALIDACIONES_DW_RRHH_mysql.sql
   10+ validaciones de calidad del Data Warehouse
   Ejecutar después de 04_ETL_RRHH_mysql.sql
   cubre el punto 9 de la actividad
   ========================================================= */

USE RRHH_DW;

-- =========================================================
-- VALIDACIÓN 1: Verificar que todas las dimensiones tienen datos
-- =========================================================

SELECT 'DimFecha' AS Dimension, COUNT(*) AS Registros FROM DimFecha
UNION ALL
SELECT 'DimOficina', COUNT(*) FROM DimOficina
UNION ALL
SELECT 'DimDepartamento', COUNT(*) FROM DimDepartamento
UNION ALL
SELECT 'DimPuesto', COUNT(*) FROM DimPuesto
UNION ALL
SELECT 'DimEmpleado', COUNT(*) FROM DimEmpleado
UNION ALL
SELECT 'DimTipoAusencia', COUNT(*) FROM DimTipoAusencia
UNION ALL
SELECT 'DimCapacitacion', COUNT(*) FROM DimCapacitacion;

-- =========================================================
-- VALIDACIÓN 2: Verificar las 4 tablas de hechos tienen datos
-- =========================================================

SELECT 'FactEmpleados' AS 'Tabla de Hecho', COUNT(*) AS Registros FROM FactEmpleados
UNION ALL
SELECT 'FactAusencias', COUNT(*) FROM FactAusencias
UNION ALL
SELECT 'FactEvaluaciones', COUNT(*) FROM FactEvaluaciones
UNION ALL
SELECT 'FactCapacitaciones', COUNT(*) FROM FactCapacitaciones;

-- =========================================================
-- VALIDACIÓN 3: Verificar integridad referencial FactEmpleados
-- =========================================================

SELECT COUNT(*) AS 'Registros Invalidos'
FROM FactEmpleados fe
LEFT JOIN DimFecha df ON fe.FechaKey = df.FechaKey
LEFT JOIN DimEmpleado de ON fe.EmpleadoKey = de.EmpleadoKey
LEFT JOIN DimOficina dof ON fe.OficinaKey = dof.OficinaKey
LEFT JOIN DimDepartamento dd ON fe.DepartamentoKey = dd.DepartamentoKey
LEFT JOIN DimPuesto dp ON fe.PuestoKey = dp.PuestoKey
WHERE df.FechaKey IS NULL 
   OR de.EmpleadoKey IS NULL 
   OR dof.OficinaKey IS NULL 
   OR dd.DepartamentoKey IS NULL 
   OR dp.PuestoKey IS NULL;

-- =========================================================
-- VALIDACIÓN 4: Verificar integridad referencial FactAusencias
-- =========================================================

SELECT COUNT(*) AS 'Registros Invalidos'
FROM FactAusencias fa
LEFT JOIN DimFecha df ON fa.FechaKey = df.FechaKey
LEFT JOIN DimEmpleado de ON fa.EmpleadoKey = de.EmpleadoKey
LEFT JOIN DimOficina dof ON fa.OficinaKey = dof.OficinaKey
LEFT JOIN DimDepartamento dd ON fa.DepartamentoKey = dd.DepartamentoKey
LEFT JOIN DimTipoAusencia dta ON fa.TipoAusenciaKey = dta.TipoAusenciaKey
WHERE df.FechaKey IS NULL 
   OR de.EmpleadoKey IS NULL 
   OR dof.OficinaKey IS NULL 
   OR dd.DepartamentoKey IS NULL 
   OR dta.TipoAusenciaKey IS NULL;

-- =========================================================
-- VALIDACIÓN 5: Verificar integridad referencial FactEvaluaciones
-- =========================================================

SELECT COUNT(*) AS 'Registros Invalidos'
FROM FactEvaluaciones fev
LEFT JOIN DimFecha df ON fev.FechaKey = df.FechaKey
LEFT JOIN DimEmpleado de ON fev.EmpleadoKey = de.EmpleadoKey
LEFT JOIN DimEmpleado dev ON fev.EvaluadorEmpleadoKey = dev.EmpleadoKey
LEFT JOIN DimOficina dof ON fev.OficinaKey = dof.OficinaKey
LEFT JOIN DimDepartamento dd ON fev.DepartamentoKey = dd.DepartamentoKey
LEFT JOIN DimPuesto dp ON fev.PuestoKey = dp.PuestoKey
WHERE df.FechaKey IS NULL -- un campo sin valor asignado
   OR de.EmpleadoKey IS NULL 
   OR dev.EmpleadoKey IS NULL 
   OR dof.OficinaKey IS NULL 
   OR dd.DepartamentoKey IS NULL 
   OR dp.PuestoKey IS NULL;

-- =========================================================
-- VALIDACIÓN 6: Verificar integridad referencial FactCapacitaciones
-- =========================================================

SELECT COUNT(*) AS 'Registros Invalidos'
FROM FactCapacitaciones fc
LEFT JOIN DimFecha df ON fc.FechaKey = df.FechaKey
LEFT JOIN DimEmpleado de ON fc.EmpleadoKey = de.EmpleadoKey
LEFT JOIN DimCapacitacion dc ON fc.CapacitacionKey = dc.CapacitacionKey
LEFT JOIN DimOficina dof ON fc.OficinaKey = dof.OficinaKey
LEFT JOIN DimDepartamento dd ON fc.DepartamentoKey = dd.DepartamentoKey
LEFT JOIN DimPuesto dp ON fc.PuestoKey = dp.PuestoKey
WHERE df.FechaKey IS NULL 
   OR de.EmpleadoKey IS NULL 
   OR dc.CapacitacionKey IS NULL 
   OR dof.OficinaKey IS NULL 
   OR dd.DepartamentoKey IS NULL 
   OR dp.PuestoKey IS NULL;

-- =========================================================
-- VALIDACIÓN 7: Verificar salarios negativos o cero
-- =========================================================

SELECT COUNT(*) AS 'Salarios Invalidos'
FROM FactEmpleados
WHERE SalarioActual <= 0;

-- =========================================================
-- VALIDACIÓN 8: Verificar calificaciones fuera de rango (1-5)
-- =========================================================

SELECT COUNT(*) AS 'Calificaciones Invalidas'
FROM FactEvaluaciones
WHERE Calificacion < 1.0 OR Calificacion > 5.0;

-- =========================================================
-- VALIDACIÓN 9: Verificar días de ausencia negativos
-- =========================================================

SELECT COUNT(*) AS 'Dias de Ausencia Negativos'
FROM FactAusencias
WHERE DiasAusencia < 0;

-- =========================================================
-- VALIDACIÓN 10: Verificar costos de capacitación negativos
-- =========================================================

SELECT COUNT(*) AS 'Costos Negativos'
FROM FactCapacitaciones
WHERE CostoCapacitacion < 0;

-- =========================================================
-- VALIDACIÓN 11: Verificar calificaciones de capacitación fuera de rango
-- =========================================================

SELECT COUNT(*) AS 'Calificaciones de Capacitacion Invalidas'
FROM FactCapacitaciones
WHERE CalificacionObtenida IS NOT NULL 
  AND (CalificacionObtenida < 0 OR CalificacionObtenida > 100);

-- =========================================================
-- VALIDACIÓN 12: Verificar consistencia de conteo OLTP vs DWH
-- =========================================================

SELECT 
    'Empleados' AS Tabla,
    (SELECT COUNT(*) FROM RRHH_OLTP.Empleados) AS OLTP,
    (SELECT COUNT(*) FROM DimEmpleado) AS DWH_Dim,
    (SELECT COUNT(*) FROM FactEmpleados) AS DWH_Fact, -- Nota: !!la razon del error es que cuando se estabrece Dimfecha se pone un limite a segemento de tiempo de carga de datos¡¡
    CASE WHEN (SELECT COUNT(*) FROM RRHH_OLTP.Empleados) = (SELECT COUNT(*) FROM FactEmpleados)
         THEN 'OK' ELSE 'ERROR' END AS Estado
UNION ALL
SELECT 
    'Ausencias',
    (SELECT COUNT(*) FROM RRHH_OLTP.Ausencias),
    (SELECT COUNT(*) FROM DimTipoAusencia),
    (SELECT COUNT(*) FROM FactAusencias),
    CASE WHEN (SELECT COUNT(*) FROM RRHH_OLTP.Ausencias) = (SELECT COUNT(*) FROM FactAusencias)
         THEN 'OK' ELSE 'ERROR' END
UNION ALL
SELECT 
    'Evaluaciones',
    (SELECT COUNT(*) FROM RRHH_OLTP.EvaluacionesDesempeno),
    (SELECT COUNT(*) FROM DimEmpleado),
    (SELECT COUNT(*) FROM FactEvaluaciones),
    CASE WHEN (SELECT COUNT(*) FROM RRHH_OLTP.EvaluacionesDesempeno) = (SELECT COUNT(*) FROM FactEvaluaciones)
         THEN 'OK' ELSE 'ERROR' END
UNION ALL
SELECT 
    'Capacitaciones_Asignadas',
    (SELECT COUNT(*) FROM RRHH_OLTP.EmpleadosCapacitaciones),
    (SELECT COUNT(*) FROM DimCapacitacion),
    (SELECT COUNT(*) FROM FactCapacitaciones),
    CASE WHEN (SELECT COUNT(*) FROM RRHH_OLTP.EmpleadosCapacitaciones) = (SELECT COUNT(*) FROM FactCapacitaciones)
         THEN 'OK' ELSE 'ERROR' END;

-- =========================================================
-- VALIDACIÓN 13: Verificar duplicados en dimensiones
-- =========================================================

SELECT 'DimEmpleado' AS Dimension, 
       COUNT(*) - COUNT(DISTINCT EmpleadoID_OLTP) AS Duplicados
FROM DimEmpleado
UNION ALL
SELECT 'DimOficina',
       COUNT(*) - COUNT(DISTINCT OficinaID_OLTP)
FROM DimOficina
UNION ALL
SELECT 'DimDepartamento',
       COUNT(*) - COUNT(DISTINCT DepartamentoID_OLTP)
FROM DimDepartamento;

-- =========================================================
-- VALIDACIÓN 14: Verificar fechas fuera del rango esperado
-- =========================================================

SELECT COUNT(*) AS 'Fechas Fuera de Rango Empleados'
FROM FactEmpleados fe
JOIN DimFecha df ON fe.FechaKey = df.FechaKey
WHERE df.Anio < 2023 OR df.Anio > 2025

UNION ALL

SELECT COUNT(*) AS FechasFueraRango_Ausencias
FROM FactAusencias fa
JOIN DimFecha df ON fa.FechaKey = df.FechaKey
WHERE df.Anio < 2023 OR df.Anio > 2025

UNION ALL

SELECT COUNT(*) AS FechasFueraRango_Evaluaciones
FROM FactEvaluaciones fev
JOIN DimFecha df ON fev.FechaKey = df.FechaKey
WHERE df.Anio < 2023 OR df.Anio > 2025

UNION ALL

SELECT COUNT(*) AS FechasFueraRango_Capacitaciones
FROM FactCapacitaciones fc
JOIN DimFecha df ON fc.FechaKey = df.FechaKey
WHERE df.Anio < 2023 OR df.Anio > 2025;

-- =========================================================
-- VALIDACIÓN 15: Verificar que todos los empleados tienen jefe asignado
-- =========================================================
SELECT '15. Verificar empleados sin jefe asignado' AS Validacion;

SELECT COUNT(*) AS 'Empleados Sin Jefe'
FROM DimEmpleado
WHERE Activo = 1 AND JefeID_OLTP IS NULL;

-- =========================================================
-- RESUMEN FINAL
-- =========================================================
-- Resumen de estado general
SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM FactEmpleados) > 0 
         AND (SELECT COUNT(*) FROM FactAusencias) > 0
         AND (SELECT COUNT(*) FROM FactEvaluaciones) > 0
         AND (SELECT COUNT(*) FROM FactCapacitaciones) > 0
        THEN '✅ DATA WAREHOUSE OPERATIVO - TODAS LAS TABLAS CON DATOS'
        ELSE '⚠️ DATA WAREHOUSE INCOMPLETO - FALTAN DATOS EN ALGUNA TABLA'
    END AS Estado_General;