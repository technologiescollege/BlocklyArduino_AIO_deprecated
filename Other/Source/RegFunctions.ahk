
;===============================================================================
; Function Name:	RegToVar
;===============================================================================
RegToVar(_regpath)
{
	_tampon := ""
	 _spos :=StringGetPos( _regpath, "\")
	_Key := StringLeft(_regpath, _spos)
	_spos ++
	_SubKey := StringTrimLeft(_regpath, _spos)
	_errors := 0
	Loop, %_Key%, %_Subkey%, 1, 1
		{
		IfEqual, A_LoopRegType, KEY
			Continue
		RegRead, A_Value
		_errors += ErrorLevel
		StringReplace, A_Value, A_Value, `n, ``n, A
		_tampon .= A_LoopRegType . "" . A_LoopRegKey . "" . A_LoopRegSubKey . "" . A_LoopRegName . "" . A_Value . "`n"
		}
	; suppression du dernier LF
	StringTrimRight, _tampon, _tampon, 1
	ErrorLevel := _errors
Return _tampon
}

;===============================================================================
; Function Name:	VarToReg
;===============================================================================
VarToReg(_reglist)
{
	_errors := 0
	Loop, Parse, _reglist, `n, `r
		{
		_ligne1 := _ligne2 := _ligne3 := _ligne4 := _ligne5 := ""
		StringSplit, _ligne, A_LoopField, 
		StringReplace, _ligne5, _ligne5, ``n, `n, A
		RegWrite, %_ligne1%, %_ligne2%, %_ligne3%, %_ligne4%, %_ligne5%
		_errors += ErrorLevel
		}
Return _errors
}

;===============================================================================
; Function Name:	RegToFile
;===============================================================================
RegToFile(_regpath, _file)
{
	_content := RegToVar(_regpath)
	If (_content && !ErrorLevel)
		{
		FileDelete, %_file%
		FileAppend, %_content%, %_file%
		If ErrorLevel
			ErrMsg("REG_WRSV_ERR_MSG")
		}
	Else If ErrorLevel
		ErrMsg("REG_RDSV_ERR_MSG", ErrorLevel)
Return
}

;===============================================================================
; Function Name:	RegMove (on same hive)
;===============================================================================
RegMove(_regpathsource, _regpathdest)
{
	_orig := RegToVar(_regpathsource)
	If (_orig && !ErrorLevel)
		{
		RegDeleteStd(_regpathdest)
		_dest := StringReplace(_orig, ExtractSubKeyRegPath(_regpathsource), ExtractSubKeyRegPath(_regpathdest), "All")
		_errors := VarToReg(_dest)
		If _errors
			ErrMsg("REG_WRBK_ERR_MSG", _errors)
		RegDeleteStd(_regpathsource)
		If ErrorLevel
			ErrMsg("REG_DLSBK_ERR_MSG")
		}
	Else If ErrorLevel
		ErrMsg("REG_RDBK_ERR_MSG", _errors)
Return
}

;===============================================================================
; Function Name:	Str2RegBin : convert string to Binary Value
;===============================================================================
Str2RegBin(ByRef s_chaine)
{
	s_Result := ""
	SetFormat, IntegerFast, H
	Loop, % StrLen(s_chaine)
		{
		_ms := _ls := ""
		_ls .= SubStr(NumGet(s_chaine,(A_Index-1)*2, "UChar"), 3)
		_ms .= SubStr(NumGet(s_chaine,(A_Index-1)*2+1, "UChar"), 3)
		s_Result .= ((StrLen(_ls) = 1) ? "0" _ls : _ls) ((StrLen(_ms) = 1) ? "0" _ms : _ms)
		}
	SetFormat, IntegerFast, D
Return s_Result
}

;===============================================================================
; Function Name:	RegDeleteStd : delete a registry key using standard path
;===============================================================================
RegDeleteStd(_regpath)
{
	_root := ExtractRootRegPath(_regpath)
	_subkey := ExtractSubKeyRegPath(_regpath)
	RegDelete, %_root%, %_subkey%
Return ErrorLevel
}

;===============================================================================
; Functions Names:	ExtractRootRegPath : extracts hive from a standard registry path
; 					ExtractSubKeyRegPath : extracts subkey from a standard registry path
;===============================================================================
ExtractRootRegPath(_regpath)
{
Return StringLeft(_regpath, StringGetPos(_regpath, "\"))
}

ExtractSubKeyRegPath(_regpath)
{
Return StringTrimLeft(_regpath, StringGetPos( _regpath, "\") + 1)
}






