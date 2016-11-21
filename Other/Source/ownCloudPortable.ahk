;----------------------------------------------------
; ownCloudPortable
; ----------------------------------------------------
; Par fat115
; Basé sur une idée originale de John T. Haller
; License : GPL
; Ce script permet de créer le lanceur de ownCloudPortable.
; Compiler: AutoHotkey_L (http://www.autohotkey.net/~Lexikos/AutoHotkey_L/).
; $id=ownCloudPortable.ahk $date=2016-02-07
; ----------------------------------------------------
;Copyright © 2005-2016 Framakey

;Website: http://www.framakey.org

;This software is OSI Certified Open Source Software.
;OSI Certified is a certification mark of the Open Source Initiative.

;This program is free software; you can redistribute it and/or
;modify it under the terms of the GNU General Public License
;as published by the Free Software Foundation; either version 2
;of the License, or (at your option) any later version.

;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
;GNU General Public License for more details.

;You should have received a copy of the GNU General Public License
;along with this program; if not, write to the Free Software
;Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA	02110-1301, USA.
; ----------------------------------------------------


; --- Valeurs spécifiques à l'application => à modifier lors de la création ---
_DEFAULTEXE := "ownCloud.exe"
_DEFAULTAPPDIR := "App\ownCloud"
_DEFAULTDATADIR := "Data\settings"
_LANG := "fr-FR"
; préparation de l'objet contenant d'éventuelles variables d'environnement
o_EnvVar := Object()

; --- Options : décommentez pour application, cf LogigrammeLanceur.odg pour plus d'infos ---
_HISTORY := True
_APPDATABACKUP := True
_APPDATASUBDIR := "%_APPNAME%"
;_MOZLOOP := True
;_READONLYL := true
;_NETWORKL := True
;_REGBACKUP := True
;_REGPATH := "HKEY_CURRENT_USER\Software\%_APPNAME%"
;_TESTJAVA := True

; --- EnvVar Begin ---
; o_EnvVar.Insert("MA_VARIABLE", "ceci est sa valeur")
; --- EnvVar End ---

; --- Définition du format de la chaine de lancement, cf LogigrammeLanceur.odg pour plus d'infos ---
_EXECSTRING := """%p_AppDirectory%\%f_AppExecutable%"" --confdir ""%p_DataDirUnified%"" %s_Parameters% %s_AdditionalParameters%"

;	Vous pouvez passer à la définition des sous-routines précitées si l'application le nécessite
;-----------------------------------------------------------------------------------------------

; ------------ Bibliothèques et paramètres généraux -----------
_SCRIPTVER := "2.0.1.8" ;Version du script du lanceur
#NoTrayIcon
SingleInstance ON
#Include %A_ScriptDir%
#Include Functions.ahk
#Include ini.ahk
#Include RegFunctions.ahk
#Include Notify.ahk
FileEncoding, UTF-8
p_OldWorkingDir := A_WorkingDir
SetWorkingDir %A_ScriptDir%
OnExit, QuitPortableApp

; --------- Récupération des noms application/lanceur ---------
_FULLNAME := SubStr(A_ScriptName,1,-4)
FileGetVersion, _VER, %_FULLNAME% ".exe"
_MUTEXNAME := _FULLNAME . "_" . _VER

_APPNAME := StringReplace(_FULLNAME, "Portable")
If (SubStr(_APPNAME, -1) = "_N")
	_APPNAME := StringTrimRight(_APPNAME, 2)
If (SubStr(_APPNAME, -2) = "_RO")
	_APPNAME := StringTrimRight(_APPNAME, 3)

; -------------- simulation du PLUGINSDIR de NSIS -------------
Process, Exist
i_PID := ErrorLevel
p_PluginsDir := A_Temp . "\" . _FULLNAME . "." . i_PID
FileCreateDir, %p_PluginsDir%

; ---------- chargement des traductions des messages ----------
FileInstall, Lang.ini, %p_PluginsDir%\lang.ini
Gosub LoadTranslation

; -------------------------- Test JAVA ------------------------
If _TESTJAVA
	Gosub SubTestJava

;----------------------------------------------------
;          Définition/Récupération des valeurs
;----------------------------------------------------

EnvGet, b_nosplash, NOSPLASH
; Récupération des paramètres passés au lanceur (par exemple par CAFE)
s_Parameters := ""
Loop, %0%
{
	_param := %A_Index%
	IfExist, %p_OldWorkingDir%\%_param%
		_param := p_OldWorkingDir "\" _param
	IfInString, _param, %A_Space%
		_param := """" . _param . """"
	s_Parameters .= (!s_Parameters) ? _param : " " . _param
}

; S'il existe un fichier INI, on utilise les valeurs sinon on passe sur des valeurs par défaut
ini_load(s_AppIniFile, A_ScriptDir . "\" . _FULLNAME . ".ini", "UTF-8")
b_DisableSplashScreen := ini_getValuewDefault(s_AppIniFile, _FULLNAME, "DisableSplashScreen", False)
p_AppDirectory := A_ScriptDir . "\" . ini_getValuewDefault(s_AppIniFile, _FULLNAME, "ApplicationDirectory", _DEFAULTAPPDIR)
f_AppExecutable := ini_getValuewDefault(s_AppIniFile, _FULLNAME, "ApplicationExecutable", _DEFAULTEXE)
p_DataDir := A_ScriptDir . "\" . ini_getValuewDefault(s_AppIniFile, _FULLNAME, "SettingsDirectory",  _DEFAULTDATADIR)
If _NETWORKL
	p_NetDataDir := ini_getValuewDefault(s_AppIniFile, _FULLNAME, "NetworkSettingsDirectory", "P:\Profile\" . _APPNAME)
s_CopyCustom := ini_getValuewDefault(s_AppIniFile, _FULLNAME, "CopyCustomProfile", True)
s_AdditionalParameters := ini_getValue(s_AppIniFile, _FULLNAME, "AdditionalParameters")
s_AppIniFile := ""


;-------------------------------------------------------
;Traitement conditionnel : définition de DataDirUnified
;-------------------------------------------------------
If _APPDATABACKUP
	{
	If _APPDATASUBDIR
		p_DataDirUnified := A_AppData . "\" . Dereference(_APPDATASUBDIR)
	Else
		p_DataDirUnified := A_AppData . "\" . _APPNAME
	}
Else If _READONLYL
	p_DataDirUnified := p_PluginsDir . "\settings"
Else If _NETWORKL
	p_DataDirUnified := p_NetDataDir
Else
	p_DataDirUnified := p_DataDir
	
;----------------------------------------------------
;				Vérifications
;----------------------------------------------------

; Si l'exécutable est introuvable
IfNotExist, %p_AppDirectory%\%f_AppExecutable%
	ErrMsg("NOEXEMSG")

;----------------------------------------------------
;Mise en place des variables d'environnement si besoin
;----------------------------------------------------
For _envvar, _value in o_EnvVar
	EnvSet, % _envvar, % Dereference(_value)

; Si la version portable est déjà lancée : on lance directement
If DllCall("OpenMutex", UInt, "0x00020000", Int, "0", Str, _MUTEXNAME)
	{
	Run, % Dereference(_EXECSTRING)
	ExitApp
	}

; Si la version locale est déjà lancée
Process, Exist, %_DEFAULTEXE%
If ErrorLevel
	ErrMsg("FOUNDPROCESSMSG")

; on teste s'il faut afficher le splashscreen
If !(b_DisableSplashScreen = "True" OR b_nosplash = "True")
	{
	SetTimer, UnLoadSplash, 500
	_splashid := Notify(_APPNAME, "Lancement en cours ...", "-0", "GT=192 TS=14", A_ScriptDir "\App\AppInfo\appicon_48.png")
	}

;----------------------------------------------------
;	Traitement conditionnel : maintien historique
;----------------------------------------------------

If _HISTORY
	{
	IniRead, s_LastDataDir, %p_DataDir%\PortableHistory.ini, History, LastDataDir
	If ((s_LastDataDir != p_DataDirUnified) && (s_LastDataDir != "ERROR"))
		b_UpDataPath := True
	IniRead, s_LastAppDir, %p_DataDir%\PortableHistory.ini, History, LastAppDir
	If ((s_LastAppDir != A_ScriptDir) && (s_LastDataDir != "ERROR"))
		b_UpAppPath := True
	SplitPath, A_ScriptDir, , s_BaseDir, , , s_AppDrive
	SplitPath, s_LastAppDir, , s_LastBaseDir, , , s_LastAppDrive
	}

;----------------------------------------------------
;	Traitement conditionnel : recopie de p_DataDir
;----------------------------------------------------
If _APPDATABACKUP
; Sauvegarde des préférences de l'application locale
	IfExist, %p_DataDirUnified%\*.*
		{
		FileMoveDir, %p_DataDirUnified%, %p_DataDirUnified%-BackupBy%_FULLNAME%
		If ErrorLevel
			ErrMsg("APPDATABK_ERR_MSG")
		}

; en cas d'utilisation réseau, on vérifie s'il faut copier les préférences par défaut dans le profil réseau
If _NETWORKL
	{
	If (s_CopyCustom && !FileExist(p_NetDataDir))
		FileCopyDir, %p_DataDir%, %p_NetDataDir%
	p_DataDir := p_NetDataDir
	}

If (_APPDATABACKUP || _READONLYL || _NETWORKL)
; Copie des préférences de l'application portable
	{
	If (s_CopyCustom && !FileExist(p_DataDirUnified))
		FileCopyDir, %p_DataDir%, %p_DataDirUnified%
	If ErrorLevel
		ErrMsg("CPYPREF_ERR_MSG")
	If (_READONLYL || _NETWORKL)
		FileDelete, %p_DataDirUnified%\PortableHistory.ini
	}

; inutile d'essayer d'appliquer des modifs sur qqch qui n'existe pas
If FileExist(p_DataDirUnified)
{
	If b_UpDataPath
		Gosub UpdateSettings_DataPath
	If b_UpAppPath
		Gosub UpdateSettings_AppPath
}

;----------------------------------------------------
;	Traitement conditionnel : sauvegarde de REGPATH
;----------------------------------------------------
If _REGBACKUP
	{
	If !_REGPATH
		_REGPATH := "HKEY_CURRENT_USER\Software\" . _APPNAME
	Else
		_REGPATH := Dereference(_REGPATH)
	; Sauvegarde des préférences de l'application locale
	RegMove(_REGPATH, _REGPATH . "-BackupBy" . _FULLNAME)
	; Mise en place des préférences de l'application locale
	IfExist, %p_DataDirUnified%\%_APPNAME%.ahkreg
		{
		FileRead, _reglist, %p_DataDirUnified%\%_APPNAME%.ahkreg
		If b_UpDataPath
			Gosub UpdateRegFile_DataPath
		If b_UpAppPath
			Gosub UpdateRegFile_AppPath
		_errors := VarToReg(_reglist)
		; traitement des erreurs
		If _errors
			ErrMsg("REG_WRST_ERR_MSG", _errors)
		}
	}

;----------------------------------------------------
;					Exécution
;----------------------------------------------------
; Première instance portable : on crée un mutex
DllCall("CreateMutex", Int, 0, Int, 0, Str, _MUTEXNAME)
; Lancement de l'application
SetWorkingDir %p_AppDirectory%
RunWait, % Dereference(_EXECSTRING), , , _pid

;----------------------------------------------------
;	Traitement conditionnel : boucle MOZILLA
;----------------------------------------------------
If _MOZLOOP
	{
	; on donne 0.5s au processus pour se relancer
	Sleep, 500
	Process, Exist, %f_AppExecutable%
	If ErrorLevel
		Process, WaitClose, %f_AppExecutable%
	}

;----------------------------------------------------
;	Traitement conditionnel : maintien historique
;----------------------------------------------------
If (_HISTORY && !_READONLYL)
	{
	IniWrite, %p_DataDirUnified%, %p_DataDirUnified%\PortableHistory.ini, History, LastDataDir
	IniWrite, %A_ScriptDir%, %p_DataDirUnified%\PortableHistory.ini, History, LastAppDir
	}

;----------------------------------------------------
;	Traitement conditionnel : Permutation du registre
;----------------------------------------------------
If _REGBACKUP
	{
	; export de la branche REGPATH
	If !_READONLYL
		RegToFile(_REGPATH, p_DataDirUnified . "\" . _APPNAME . ".ahkreg")
	; effacement systématique de la clé
	RegDeleteStd(_REGPATH)
	; restauration de la branche fixe
	RegMove(_REGPATH . "-BackupBy" . _FULLNAME, _REGPATH)
	}

;----------------------------------------------------
;Traitement conditionnel : permutation dans APPDATA
;----------------------------------------------------
If _APPDATABACKUP
	{
	; enregistrement des préférences portables
	If !_READONLYL
		{
		FileRemoveDir, %p_DataDir%, 1
		FileMoveDir, %p_DataDirUnified%, %p_DataDir%, 1
		If ErrorLevel
			ErrMsg("CPYPREFBK_ERR_MSG")
		}
	; restauration des préférences fixes
	IfExist %p_DataDirUnified%-BackupBy%_FULLNAME%
		{
		FileMoveDir, %p_DataDirUnified%-BackupBy%_FULLNAME%, %p_DataDirUnified%, 1
		If ErrorLevel
			ErrMsg("APPDATART_ERR_MSG")
		}
	}

ExitApp

;===============================================================================
; Function Name:	Dereference
;===============================================================================
Dereference(_var)
{
	Transform, _value, Deref, % _var
Return _value
}

;===============================================================================
; Function Name:	ErrMsg
;===============================================================================
ErrMsg(_errname, _errnb = "", _exit=1)
{
	Global o_MsgTrans
	Global _FULLNAME

	_message := Dereference(o_MsgTrans[_errname])
	If _errnb
		_message := "Err:" . _errnb . "`n" . _message
	MsgBox, 48, %_FULLNAME%, %_message%
	If _exit
		ExitApp
	Else
		Return
}

;===============================================================================
; Function Name:	WinChildExist
;===============================================================================
WinChildExist(_parent_pid)
{
	_result := False
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		{
		If (process.ParentProcessId = _parent_pid)
			_result += WinExist("ahk_pid " . process.ProcessId)
		}
Return _result
}

;===============================================================================
; Function Name:	Path2WSAPI_URI
;===============================================================================
Path2WSAPI_URI(_path)
{
	_string := StringReplace(_path, "\", "/", "All")
	f = %A_FormatInteger%
	SetFormat, Integer, H
	pos = 1
	Loop
		If pos := RegExMatch(_string, "i)[^\/\w\.~`:%&=-]", char, pos++)
			StringReplace, _string, _string, %char%, % "%" . Asc(char), All ;"
		Else Break
	SetFormat, Integer, %f%
	_result := "file:///" . StringReplace(_string, "0x", "", "All")
Return _result
}

;===============================================================================
; Function Name:	UpdateObjectInFile
;===============================================================================
UpdateObjectInFile(_file, _object, _codepage="CP1252", _newline="CRLF")
{
	FileRead, _content, %_file%
	For key, value in _object
		_content := RegExReplace(_content, "i)\b\Q" key "\E", value)
	FileDelete, %_file%
	If (_newline = "LF")
		{
		_content := StringReplace(_content, "`r", "", "All")
		_binmode := "*"
		}
	Else
		_binmode := ""
	FileAppend, %_content%, %_binmode%%_file%, %_codepage%
}

;===============================================================================
; 							Subroutines
;===============================================================================

QuitPortableApp:
{
	; On efface le dossier temporaire
	FileRemoveDir, %p_PluginsDir%, 1
ExitApp
Return
}

UnLoadSplash:
{
	If _pid
		{
		If (WinExist("ahk_pid " . _pid) || WinChildExist(_pid))
			{
			SetTimer, UnLoadSplash, Off
			Notify("","",-1,"Wait", _splashid)
			}
		}
Return
}

LoadTranslation:
{
ini_load(s_LangFile, p_PluginsDir . "\lang.ini", "UTF-8")
_allkeys := ini_getAllKeyNames(s_LangFile, _LANG)
o_MsgTrans := Object()
Loop, parse, _allkeys, `,
	{
	o_MsgTrans[A_LoopField] := ini_getValue(s_LangFile, _LANG, A_LoopField)
	}
Return
}

SubTestJava:
{
	Loop, HKLM, SOFTWARE\JavaSoft\Java Runtime Environment, 1, 1
		{
		If (A_LoopRegName = "CurrentVersion")
			RegRead, _javaversion
		IfInString, A_LoopRegName, FamilyVersion
			RegRead, _javacompleteversion
		If (A_LoopRegName = "JavaHome")
			{
			RegRead, _javahome
			IfNotExist, %_javahome%\bin\javaw.exe
				_javahome := False
			}
		}
	If !_javahome
		ErrMsg("NOJAVAMSG")
Return
}

;===============================================================================
; 						Modifications à apporter
;===============================================================================
; modifications à apporter au fichier registre suivant l'emplacement du "profil"
; rappel : le fichier registre est chargé dans la variable _reglist
UpdateRegFile_DataPath:
{
	
Return
}

; modifications à apporter au fichier registre suivant l'emplacement de l'application
UpdateRegFile_AppPath:
{
	
Return
}

; modifications à apporter au "profil" suivant son emplacement
UpdateSettings_DataPath:
{
	
Return
}

; modifications à apporter au "profil" suivant l'emplacement de l'application
UpdateSettings_AppPath:
{
	o_FKPath := Object()
	o_FKPath.Insert("localPath=" . s_LastAppDrive,"localPath=" . s_AppDrive)
	UpdateObjectInFile(p_DataDirUnified "\owncloud.cfg", o_FKPath, "UTF-8-RAW", "CRLF")
Return
}



