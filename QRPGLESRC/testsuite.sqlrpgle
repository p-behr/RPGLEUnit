**free 

ctl-opt nomain;
ctl-opt options(*nodebugio:*srcstmt);
ctl-opt bnddir('TESTSUITE');

/copy './testsuite_h'

// Error Code data structure to force error message percolation.
// No bytes provided. If an error occurs, an exception is returned to
// the caller to indicate that the requested function failed.
dcl-ds errorDs_t  template;
    bytesProvided  int(10) inz(0);
    bytesAvailable int(10) inz(0);
end-ds;

//==============================================================================
// Get Test Suite Info
//==============================================================================
dcl-proc  GetTestSuiteInfo  export;
    dcl-pi *n likeds(testSuiteInfo_t);
        testSuite  char(10) const;
        in_library    char(10) const options(*nopass : *omit);
    end-pi;

    dcl-s  library  char(10) inz('*LIBL');
    dcl-s  procList  char(10)  dim(*auto : 32000);
    dcl-s  pgmMark  int(10);
    dcl-s  i  uns(5);
    dcl-s  x  uns(5);
    dcl-ds testSuiteInfo  likeds(testSuiteInfo_t) inz;

    if %parms >= %parmnum(in_library)
    and %addr(in_library) <> *null
    and in_library <> *blanks;
        library = in_library;
    endif;

    // Get list of all exported procedures
    exsr GetProcedureList;

    // Activate the test suite (service program)
    pgmMark = ActivateSrvPgm(testSuite : library);

    // Spin through all the procedures, get a pointer
    // to each of them, and load testSuiteInfo
    for i = 1 to %elem(procList);
        select;
            when procInfo.name = 'SETUPSUITE';
                testSuiteInfo.setupSuite = GetProcedurePointer(pgmMark : procList(i));
            when procInfo.name = 'SETUP';
                testSuiteInfo.setup = GetProcedurePointer(pgmMark : procList(i));
            when procInfo.name = 'TEARDOWN';
                testSuiteInfo.teardown = GetProcedurePointer(pgmMark : procList(i));
            when procInfo.name = 'TEARDOWNSUITE';
                testSuiteInfo.teardownSuite = GetProcedurePointer(pgmMark : procList(i));
            when %subst(procInfo.name : 1 : 4) = 'TEST';
                testSuiteInfo.testCount += 1;
                x = testSuiteInfo.testCount;
                testCases(x).name = procList(i);
                testCases(x).addr = GetProcedurePointer(pgmMark : procList(i));
        endsl;
    endfor;
    
    return  testSuiteInfo;

    // ------------------------------------------------------------
    begsr GetProcedureList;

        Exec SQL
        DECLARE procedure_list_cursor CURSOR FOR
        SELECT symbol_name
        FROM qsys2.program_export_import_info
        WHERE program_library = :library
        AND program_name = :testSuite
        AND symbol_usage = '*PROCEXP';

        Exec SQL
        OPEN procedure_list_cursor;

        Exec SQL
        FETCH procedure_list_cursor
        FOR 32000 ROWS
        INTO :procList;

        Exec SQL
        CLOSE procedure_list_cursor;
     
    endsr;

end-proc  GetTestSuiteInfo;



//==============================================================================
// Activate the service program so that we can get pointers to the procedures
//==============================================================================
dcl-proc  ActivateSrvPgm;
    dcl-pi  *n  int(10);
        srvpgmName  char(10) const;
        library  char(10) const;
    end-pi;

    dcl-pr  ConvertTypeAPI  extpgm('QCLICVTTP');
        conversionType    char(10) const;
        symbolicType      char(10) const;
        hexType           char(2);
        errorDs           likeds(errorDs) options(*omit : *noopt);
    end-pr;

    dcl-pr  ResolveSystemPointer  pointer(*proc)  extproc('rslvsp');
        hexObjectType     char(2)  value;
        objectName        pointer  value options(*string);
        library           pointer  value options(*string);
        authority         char(2)  value;
    end-pr;

    dcl-pr  ActivateBoundProgram  int(10)  extproc('QleActBndPgm');
        systemPointer     pointer(*proc) const;
        activationMark    int(10) options(*omit);
        activationInfo    char(64) options(*omit);
        infoLength        int(10) const options(*omit);
        errors            likeds(errorDs) options(*omit) noopt;
    end-pr;

    dcl-s  objectType  char(2);
    dcl-ds errorDs  likeds(errorDs_t) inz;
    dcl-s  sysPtr  pointer(*proc);
    dcl-s  auth  char(2)  inz(*loval);
    dcl-s  mark  int(10);

    // Convert the symbolic object type "*SRVPGM" to the system hex object type.
    // I can't imagine this would ever change (so it could probably be a constant)
    // but we'll fetch it dynamically anyway.
    ConvertTypeAPI('*SYMTOHEX' : '*SRVPGM' : objectType : errorDs);

    // Get a system pointer to the service program object
    sysPtr = ResolveSystemPointer( objectType
                                 : srvpgmName
                                 : library
                                 : auth
                                 );

    // Use the system pointer to activate the service program
    mark = ActivateBoundProgram(sysPtr : *omit : *omit : *omit : *omit);

    return mark;
end-proc  ActivateSrvPgm;


//==============================================================================
// Get a pointer to a procedure
//==============================================================================
dcl-proc  GetProcedurePointer;
    dcl-pi  *n  pointer(*proc);
        srvPgmMark  int(10) const;
        procName    varchar(256) const;
    end-pi;

    dcl-pr GetExport  pointer(*proc) extproc(QleGetExp);
        activationMark  int(10) const       options(*omit);
        exportNumber    int(10) const       options(*omit);
        nameLength      int(10) const       options(*omit);
        procedureName   varchar(256)        options(*omit);
        procedureAddr   pointer(*proc)      options(*omit);
        exportType      int(10)             options(*omit);
        errorDs         likeds(errorDs_t)   options(*omit);
    end-pr;

    dcl-s addr  pointer(*proc);

    // Get export.
    GetExport( actMark :
               0 :
               %len(proc.procNm) :
               proc.procNm :
               proc.procPtr :
               exportType :
               percolateErrors );

    return addr;
end-proc  GetProcedurePointer;
