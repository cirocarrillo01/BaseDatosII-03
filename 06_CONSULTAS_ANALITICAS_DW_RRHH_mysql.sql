/* =========================================================
   06_CONSULTAS_ANALITICAS_DW_RRHH_mysql
   15 consultas analíticas para el Data Warehouse de RRHH
   Ejecutar después de 04_ETL_RRHH_mysql.sql
   cubre el punto 10 de la actividad
   ========================================================= */

USE RRHH_DW;

-- =========================================================
-- CONSULTA 1: Total de empleados activos por región y año
-- =========================================================
SELECT 
    dof.Region,
    df.Anio,
    COUNT(DISTINCT fe.EmpleadoKey) AS 'Total Empleados Activos'
FROM FactEmpleados fe
JOIN DimOficina dof ON fe.OficinaKey = dof.OficinaKey
JOIN DimFecha df ON fe.FechaKey = df.FechaKey
WHERE fe.Activo = 1
GROUP BY dof.Region, df.Anio
ORDER BY dof.Region, df.Anio;

-- =========================================================
-- CONSULTA 2: Promedio salarial por nivel de puesto y departamento
-- =========================================================
SELECT 
    dp.NivelSalarial as 'Nivel salarial',
    dd.NombreDepartamento as 'Nombre De Departamento',
    ROUND(AVG(fe.SalarioActual), 2) AS Salario_Promedio,
    COUNT(fe.EmpleadoKey) AS 'Cantidad de Empleados'
FROM FactEmpleados fe
JOIN DimPuesto dp ON fe.PuestoKey = dp.PuestoKey
JOIN DimDepartamento dd ON fe.DepartamentoKey = dd.DepartamentoKey
WHERE fe.Activo = 1
GROUP BY dp.NivelSalarial, dd.NombreDepartamento
ORDER BY dp.NivelSalarial, Salario_Promedio DESC;

-- =========================================================
-- CONSULTA 3: Evolución mensual de ausencias por tipo
-- =========================================================
SELECT 
    df.Anio as 'año',
    df.Mes as 'Mes',
    df.NombreMes as 'Nombre Mes',
    dta.TipoAusencia as 'Tipo de ausencia',
    SUM(fa.CantidadAusencias) AS 'Total de Ausencias',
    SUM(fa.DiasAusencia) AS TotalDiasPerdidos,
    ROUND(AVG(fa.DiasAusencia), 2) AS 'Promedio Dias Por Ausencia'
FROM FactAusencias fa
JOIN DimFecha df ON fa.FechaKey = df.FechaKey
JOIN DimTipoAusencia dta ON fa.TipoAusenciaKey = dta.TipoAusenciaKey
GROUP BY df.Anio, df.Mes, df.NombreMes, dta.TipoAusencia
ORDER BY df.Anio, df.Mes, TotalDiasPerdidos DESC;

-- =========================================================
-- CONSULTA 4: Top 10 empleados con mejor calificación promedio
-- =========================================================
SELECT 
    de.NombreCompleto as 'Nombre Completo',
    dd.NombreDepartamento as 'Nombre de Departamento',
    ROUND(AVG(fev.Calificacion), 2) AS PromedioCalificacion,
    COUNT(fev.FactEvaluacionKey) AS 'Numero de Evaluaciones'
FROM FactEvaluaciones fev
JOIN DimEmpleado de ON fev.EmpleadoKey = de.EmpleadoKey
JOIN DimDepartamento dd ON fev.DepartamentoKey = dd.DepartamentoKey
GROUP BY de.NombreCompleto, dd.NombreDepartamento
HAVING COUNT(fev.FactEvaluacionKey) >= 2
ORDER BY PromedioCalificacion DESC
LIMIT 10;

-- =========================================================
-- CONSULTA 5: Distribución de género por departamento
-- =========================================================
SELECT 
    dd.NombreDepartamento as 'Nombre de departamento',
    de.Genero as 'Genero',
    COUNT(*) AS 'Cantidad de Empleados',
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY dd.NombreDepartamento), 2) AS 'Porcentaje'
FROM DimEmpleado de
JOIN DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
WHERE de.Activo = 1
GROUP BY dd.NombreDepartamento, de.Genero
ORDER BY dd.NombreDepartamento, de.Genero;

-- =========================================================
-- CONSULTA 6: Costo total en capacitaciones por región y año
-- =========================================================
SELECT 
    dof.Region as 'region',
    df.Anio as 'año',
    COUNT(fc.FactCapacitacionKey) AS 'Total de Capacitaciones',
    SUM(fc.CostoCapacitacion) AS 'Costo Total',
    ROUND(AVG(fc.CostoCapacitacion), 2) AS 'Costo Promedio'
FROM FactCapacitaciones fc
JOIN DimOficina dof ON fc.OficinaKey = dof.OficinaKey
JOIN DimFecha df ON fc.FechaKey = df.FechaKey
GROUP BY dof.Region, df.Anio
ORDER BY dof.Region, df.Anio;

-- =========================================================
-- CONSULTA 7: Relación entre evaluaciones y calificaciones de capacitaciones
-- =========================================================
SELECT 
    de.NombreCompleto as 'Nombre Completo',
    ROUND(AVG(fev.Calificacion), 2) AS PromedioEvaluacion,
    COUNT(DISTINCT fc.CapacitacionKey) AS 'Total Capacitaciones',
    ROUND(AVG(fc.CalificacionObtenida), 2) AS 'Promedio de Capacitacion'
FROM DimEmpleado de
LEFT JOIN FactEvaluaciones fev ON de.EmpleadoKey = fev.EmpleadoKey
LEFT JOIN FactCapacitaciones fc ON de.EmpleadoKey = fc.EmpleadoKey
WHERE de.Activo = 1
GROUP BY de.NombreCompleto
HAVING COUNT(fev.FactEvaluacionKey) > 0
ORDER BY PromedioEvaluacion DESC
LIMIT 10;

-- =========================================================
-- CONSULTA 8: Tasa de ausentismo por departamento (días perdidos)
-- =========================================================
SELECT 
    dd.NombreDepartamento as 'Nombre de Departamento',
    df.Anio as 'año',
    SUM(fa.DiasAusencia) AS TotalDiasAusencia,
    COUNT(DISTINCT fa.EmpleadoKey) AS 'Empleados Con Ausencias',
    ROUND(SUM(fa.DiasAusencia) / NULLIF(COUNT(DISTINCT fa.EmpleadoKey), 0), 2) AS 'Promedio Dias Por Empleado'
FROM FactAusencias fa
JOIN DimDepartamento dd ON fa.DepartamentoKey = dd.DepartamentoKey
JOIN DimFecha df ON fa.FechaKey = df.FechaKey
GROUP BY dd.NombreDepartamento, df.Anio
ORDER BY TotalDiasAusencia DESC;

-- =========================================================
-- CONSULTA 9: Análisis de brecha salarial por género
-- =========================================================
WITH salarios_genero AS (
    SELECT 
        de.Genero,
        dd.NombreDepartamento,
        dp.NivelSalarial,
        fe.SalarioActual,
        COUNT(*) OVER (PARTITION BY de.Genero) AS TotalPorGenero
    FROM FactEmpleados fe
    JOIN DimEmpleado de ON fe.EmpleadoKey = de.EmpleadoKey
    JOIN DimDepartamento dd ON fe.DepartamentoKey = dd.DepartamentoKey
    JOIN DimPuesto dp ON fe.PuestoKey = dp.PuestoKey
    WHERE fe.Activo = 1
)
SELECT 
    Genero,
    COUNT(*) AS 'Cantidad de Empleados',
    ROUND(MIN(SalarioActual), 2) AS 'Salario Minimo',
    ROUND(MAX(SalarioActual), 2) AS 'Salario Maximo',
    ROUND(AVG(SalarioActual), 2) AS SalarioPromedio,
    ROUND(AVG(SalarioActual) / 
        (SELECT AVG(SalarioActual) FROM FactEmpleados fe2 
         JOIN DimEmpleado de2 ON fe2.EmpleadoKey = de2.EmpleadoKey 
         WHERE fe2.Activo = 1) * 100, 2) AS 'Porcentaje Vs Promedio Global'
FROM salarios_genero
GROUP BY Genero
ORDER BY SalarioPromedio DESC;

-- =========================================================
-- CONSULTA 10: Tendencia de contrataciones por trimestre
-- =========================================================
SELECT 
    df.Anio as 'año',
    df.Trimestre as 'trimestre',
    COUNT(fe.FactEmpleadoKey) AS 'Nuevas Contrataciones',
    SUM(fe.SalarioActual) AS 'Gasto Salarial Nuevas Contrataciones'
FROM FactEmpleados fe
JOIN DimFecha df ON fe.FechaKey = df.FechaKey
GROUP BY df.Anio, df.Trimestre
ORDER BY df.Anio, df.Trimestre;

-- =========================================================
-- CONSULTA 11: Empleados con mayor antigüedad
-- =========================================================
SELECT 
    de.NombreCompleto as 'Nombre Completo',
    de.AntiguedadAnios as 'Antiguedad años',
    dd.NombreDepartamento as 'Nombre de Departamento',
    ROUND(AVG(fev.Calificacion), 2) AS 'Promedio de Evaluacion'
FROM DimEmpleado de
JOIN DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
LEFT JOIN FactEvaluaciones fev ON de.EmpleadoKey = fev.EmpleadoKey
WHERE de.Activo = 1
GROUP BY de.NombreCompleto, de.AntiguedadAnios, dd.NombreDepartamento
ORDER BY de.AntiguedadAnios DESC
LIMIT 10;

-- =========================================================
-- CONSULTA 12: Estado de capacitaciones por empleado
-- =========================================================
SELECT 
    de.NombreCompleto as 'Nombre completo',
    dd.NombreDepartamento as 'Nombre de Departamento',
    COUNT(CASE WHEN fc.Estado = 'Completada' THEN 1 END) AS CapacitacionesCompletadas,
    COUNT(CASE WHEN fc.Estado = 'En Curso' THEN 1 END) AS 'Capacitaciones En Curso',
    ROUND(AVG(fc.CalificacionObtenida), 2) AS 'Promedio de Calificacion Capacitaciones'
FROM DimEmpleado de
JOIN DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
LEFT JOIN FactCapacitaciones fc ON de.EmpleadoKey = fc.EmpleadoKey
WHERE de.Activo = 1
GROUP BY de.NombreCompleto, dd.NombreDepartamento
ORDER BY CapacitacionesCompletadas DESC
LIMIT 10;

-- =========================================================
-- CONSULTA 13: Top 10 empleados con mayor número de ausencias
-- =========================================================
SELECT 
    de.NombreCompleto as 'Nombre Completo',
    dd.NombreDepartamento as 'Nombre de Departamento',
    COUNT(fa.FactAusenciaKey) AS TotalAusencias,
    SUM(fa.DiasAusencia) AS 'Total Dias Ausencia',
    ROUND(AVG(fa.DiasAusencia), 2) AS 'Promedio Dias Por Ausencia'
FROM DimEmpleado de
JOIN FactAusencias fa ON de.EmpleadoKey = fa.EmpleadoKey
JOIN DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
WHERE de.Activo = 1
GROUP BY de.NombreCompleto, dd.NombreDepartamento
ORDER BY TotalAusencias DESC
LIMIT 10;

-- =========================================================
-- CONSULTA 14: Evaluadores con mejores calificaciones otorgadas
-- =========================================================
SELECT 
    evaluador.NombreCompleto AS 'Nombre de Evaluador',
    COUNT(fev.FactEvaluacionKey) AS 'Total Evaluaciones',
    ROUND(AVG(fev.Calificacion), 2) AS PromedioCalificacionOtorgada
FROM FactEvaluaciones fev
JOIN DimEmpleado evaluador ON fev.EvaluadorEmpleadoKey = evaluador.EmpleadoKey
GROUP BY evaluador.NombreCompleto
HAVING COUNT(fev.FactEvaluacionKey) >= 3
ORDER BY PromedioCalificacionOtorgada DESC;

-- =========================================================
-- CONSULTA 15: Resumen de empleados por región
-- =========================================================
SELECT 
    dof.Region as 'Region',
    COUNT(DISTINCT de.EmpleadoKey) AS TotalEmpleados,
    ROUND(AVG(fe.SalarioActual), 2) AS 'Salario Promedio',
    SUM(fa.DiasAusencia) AS 'Total Dias Ausencia',
    COUNT(DISTINCT fc.FactCapacitacionKey) AS 'Total Capacitaciones'
FROM DimOficina dof
LEFT JOIN DimEmpleado de ON dof.OficinaID_OLTP = de.OficinaID_OLTP AND de.Activo = 1
LEFT JOIN FactEmpleados fe ON de.EmpleadoKey = fe.EmpleadoKey AND fe.Activo = 1
LEFT JOIN FactAusencias fa ON de.EmpleadoKey = fa.EmpleadoKey
LEFT JOIN FactCapacitaciones fc ON de.EmpleadoKey = fc.EmpleadoKey
GROUP BY dof.Region
ORDER BY TotalEmpleados DESC;
