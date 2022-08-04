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
        library    char(10) const;
    end-pi;

    dcl-s  procedureList  char(10)  dim(2000);
    dcl-s  procedureCount  uns(5);
    dcl-s  pgmMark  int(10);
    dcl-s  i  uns(5);
    dcl-s  name  char(10);
    dcl-s  ptr   pointer(*proc);
    dcl-s  testSuite  likeds(testSuiteInfo_t) inz;

    GetProcedureList(procedureList : procedureCount);
    pgmMark = ActivateSrvPgm(srvpgmName:library);
    for i = 1 to procedureCount;
        name = procedureList(i);
        ptr = GetProcedurePointer(pgmMark : name);
        testSuite.procedureCount = procedureCount;
        testSuite.procedures(i).name = name;
        testSuite.procedures(i).addr = ptr;
    endfor;
    
    return  testSuiteInfo;
end-proc  GetTestSuiteInfo;



//==============================================================================
// Get a list of all procedures exported by the service program
//==============================================================================
dcl-proc  GetProcedureList;
    dcl-pi  *n;
        procedureNames  char(10) dim(2000);
        procedureCount  uns(5);
    end-pi;

    dcl-s  procedures  char(10) dim(*auto : 2000);

    Exec SQL
      DECLARE proceudre_list_cursor CURSOR FOR
         SELECT symbol_name
         FROM qsys2.program_export_import_info
         WHERE program_library = :library
           AND program_name = :srvpgmName
           AND symbol_usage = '*PROCEXP';

    Exec SQL
      OPEN proceudre_list_cursor;

    Exec SQL
      FETCH proceudre_list_cursor
      INTO :procedures;

    Exec SQL
      CLOSE proceudre_list_cursor;

    return procedures;
end-proc  GetProcedureList;


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
    // but we'll fetch it dynamically anyway because I'm not sure, and APIs are fun.
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
