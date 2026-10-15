CREATE OR ALTER PROCEDURE dbo.CalculateMonthlyProfitability @MonthDate date
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @MonthStart date=DATEFROMPARTS(YEAR(@MonthDate),MONTH(@MonthDate),1);
 DECLARE @NextMonth date=DATEADD(month,1,@MonthStart);
 DECLARE @MonthEnd date=EOMONTH(@MonthDate);
 DECLARE @DateKey int=CONVERT(int,CONVERT(char(8),@MonthEnd,112));
 -- Eligibility evaluated at transaction date; calculation is reproducible for historical months.
 BEGIN TRANSACTION;
 DELETE FROM dbo.MonthlyProfitability WHERE DateKey=@DateKey;
 INSERT dbo.MonthlyProfitability(DateKey,PortfolioCode,BranchId,CustomerCode,SegmentCode,ProductCode,SubProductCode,CurrencyCode,TotalYPProfit,TotalTLProfit,TransactionCount)
 SELECT @DateKey,t.PortfolioCode,t.BranchId,t.CustomerCode,c.SegmentCode,t.ProductCode,t.SubProductCode,t.CurrencyCode,
 SUM(COALESCE(x.OverrideYPProfit,t.YPProfit)*p.Multiplier*sp.Multiplier),
 SUM(COALESCE(x.OverrideTLProfit,t.TLProfit)*p.Multiplier*sp.Multiplier),COUNT(*)
 FROM dbo.Transactions t
 JOIN dbo.Customers c ON c.CustomerCode=t.CustomerCode
 JOIN dbo.ProductSegments ps ON ps.ProductCode=t.ProductCode AND ps.SegmentCode=c.SegmentCode
 JOIN dbo.Products p ON p.ProductCode=t.ProductCode
 JOIN dbo.SubProducts sp ON sp.ProductCode=t.ProductCode AND sp.SubProductCode=t.SubProductCode
 JOIN dbo.Portfolios pf ON pf.PortfolioCode=t.PortfolioCode AND pf.BranchId=t.BranchId
 JOIN dbo.Employees e ON e.EmployeeCode=pf.EmployeeCode
 LEFT JOIN dbo.TransactionExceptions x ON x.TransactionId=t.TransactionId
 WHERE t.TransactionDate>=@MonthStart AND t.TransactionDate<@NextMonth
   AND pf.StartDate<=t.TransactionDate AND (pf.EndDate IS NULL OR pf.EndDate>=t.TransactionDate)
   AND e.StartDate<=t.TransactionDate AND (e.EndDate IS NULL OR e.EndDate>=t.TransactionDate)
 GROUP BY t.PortfolioCode,t.BranchId,t.CustomerCode,c.SegmentCode,t.ProductCode,t.SubProductCode,t.CurrencyCode;
 COMMIT TRANSACTION;
END;
GO
CREATE OR ALTER PROCEDURE dbo.GetMonthlyProfitBySegment @DateKey int
AS BEGIN SET NOCOUNT ON;
 SELECT m.DateKey,s.SegmentName,m.ProductCode,p.ProductName,SUM(m.TotalTLProfit) AS TotalTLProfit,SUM(m.TotalYPProfit) AS TotalYPProfit
 FROM dbo.MonthlyProfitability m JOIN dbo.Segments s ON s.SegmentCode=m.SegmentCode JOIN dbo.Products p ON p.ProductCode=m.ProductCode
 WHERE m.DateKey=@DateKey GROUP BY m.DateKey,s.SegmentName,m.ProductCode,p.ProductName;
END;
GO
CREATE OR ALTER PROCEDURE dbo.GetMonthlyProfitByPortfolio @DateKey int
AS BEGIN SET NOCOUNT ON;
 SELECT m.DateKey,m.PortfolioCode,m.BranchId,e.FirstName,e.LastName,SUM(m.TotalTLProfit) AS TotalTLProfit,SUM(m.TotalYPProfit) AS TotalYPProfit
 FROM dbo.MonthlyProfitability m JOIN dbo.Portfolios pf ON pf.PortfolioCode=m.PortfolioCode LEFT JOIN dbo.Employees e ON e.EmployeeCode=pf.EmployeeCode
 WHERE m.DateKey=@DateKey GROUP BY m.DateKey,m.PortfolioCode,m.BranchId,e.FirstName,e.LastName;
END;
