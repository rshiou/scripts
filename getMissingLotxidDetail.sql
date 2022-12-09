set linesize 132 pagesize 2000 echo off feedback off
SELECT ReceiptKey AS Receipt
, ReceiptLineNumber AS Line
, rd.StorerKey
, rd.Sku
, rd.ToId
, QtyReceived
FROM WH659.RECEIPTDETAIL rd
    JOIN WH659.SKU s ON rd.StorerKey = s.StorerKey AND
        rd.Sku = s.Sku AND
        s.IcdFlag = '1' AND
        rd.Status IN ('9', '11') AND
        rd.QtyReceived > 0
MINUS
SELECT lih.SourceKey
, lih.SourceLineNumber
, lih.StorerKey
, lih.Sku
, lih.Id
, COUNT(*)
FROM WH659.LOTXIDHEADER lih
    JOIN WH659.LOTXIDDETAIL lid USING (LotXIdKey)
GROUP BY lih.SourceKey, lih.SourceLineNumber, lih.StorerKey, lih.Sku, lih.Id;

exit;
