      *---------------------------------------------------------
      * UTILMOD - UTILITY PROCEDURES FOR DATE FORMATTING
      * COMPILE: CRTRPGMOD MODULE(MYLIB/UTILMOD)
      *---------------------------------------------------------
     H NOMAIN
      *
      * PROTOTYPE FOR FORMATDATE PROCEDURE
      *---------------------------------------------------------
     DFormatDate       PR            10A
     DpDate                            D   DATFMT(*ISO)
     DpFormat                         3A   CONST
      *
      *---------------------------------------------------------
      * FormatDate - Returns date as formatted string
      * pFormat values: 'ISO' = YYYY-MM-DD
      *                 'US ' = MM/DD/YYYY
      *                 'EUR' = DD.MM.YYYY
      *---------------------------------------------------------
     PFormatDate       B                   EXPORT
     DFormatDate       PI            10A
     DpDate                            D   DATFMT(*ISO)
     DpFormat                         3A   CONST
      *
     DwResult          S             10A
     DwYear            S              4A
     DwMonth           S              2A    INZ('  ')
     DwDay             S              2A    INZ('  ')
     DwMonthNum        S              2P 0
     DwDayNum          S              2P 0
      *
     C                   EVAL      wYear  = %CHAR(%SUBDT(pDate:*Y))
     C                   EVAL      wMonthNum = %SUBDT(pDate:*M)
     C                   EVAL      wDayNum =%SUBDT(pDate:*D)
      *
     C                   IF        wMonthNum < 10
     C                   EVAL      wMonth = '0' + %TRIM(%CHAR(wMonthNum))
     C                   ELSE
     C                   EVAL      wMonth = %CHAR(wMonthNum)
     C                   ENDIF
      *
     C                   IF        wDayNum < 10
     C                   EVAL      wDay  = '0' + %TRIM(%CHAR(wDayNum))
     C                   ELSE
     C                   EVAL      wDay = %CHAR(wDayNum)
     C                   ENDIF
      *
     C                   SELECT
     C                   WHEN      pFormat = 'US '
     C                   EVAL      wResult = wMonth + '/' +
     C                                       wDay   + '/' +
     C                                       wYear
     C                   WHEN      pFormat = 'EUR'
     C                   EVAL      wResult = wDay   + '.' +
     C                                       wMonth + '.' +
     C                                       wYear
     C                   OTHER
     C                   EVAL      wResult = wYear + '-' +
     C                                       wMonth + '-' +
     C                                       wDay
     C                   ENDSL
      *
     C                   RETURN    wResult
     P FORMATDATE      E
