.386
.model flat,stdcall
option casemap:none

;Dependances definitions
;include .incs
include c:\masm32\include\windows.inc
include c:\masm32\include\gdi32.inc
include c:\masm32\include\gdiplus.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\msvcrt.inc

;include .libs
includelib c:\masm32\lib\gdi32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\msvcrt.lib


.DATA

strCommand  				db  "Pause",10,0 						 										; Pause utilisé en fin de programme pour éviter la fermeture du terminal sans avoir le temps de lire les informations
strDot 						db  ".",0 			 					 										; Variable initialisée à "." pour une future fonction de comparaison
strDoubleDot				db  "..",0 								 										; Variable initialisée à ".." pour une future fonction de comparaison
strIndicationDossierCourant 	db "Dossier courant : %s %s %s",0 												; Utilisé pour afficher dans le terminal une indication
strIntro					db ",voici le contenu du dossier courant : ",10,0								; Utilisé en guise d'introduction au programme
strOutro					db "Fin du programme, tous les fichiers / dossiers ont ete listes ",10,0		; Utilisé en guise d'introduction au programme
strnull						db 10,0																			; Utilisé pour un retour à la ligne sur l'affichage
file 						byte "%s",13,10,0 						 										; Utilisé pour contenir la chaîne de caractère du fichier affiché
CurrentDir  				byte  ".\*",0							 										; Utilisé pour déterminer récursivement le dossier courant utilisé dans les différentes fonctions
tabulation 					byte "  ",0 																	; Utilisé pour améliorer l'érgonomie d'affichage dans le terminal des différents fichiers contenus dans un dossier
niveauDossier				dword 0 																		; Variable utilisé pour savoir à quel niveau on se trouve dans l'arborescence récurvise


.DATA?
datafiles 	WIN32_FIND_DATA	 <> ; Définition de la structure de donnée du fichier traité dans la récursivité et contenant un lot de paramètre défini ci-dessous

;Documentation :
;typedef struct _WIN32_FIND_DATAA {
;  DWORD    dwFileAttributes;
;  FILETIME ftCreationTime;
;  FILETIME ftLastAccessTime;
;  FILETIME ftLastWriteTime;
;  DWORD    nFileSizeHigh;
;  DWORD    nFileSizeLow;
;  DWORD    dwReserved0;
;  DWORD    dwReserved1;
;  CHAR     cFileName[MAX_PATH];
;  CHAR     cAlternateFileName[14];
;  DWORD    dwFileType;
;  DWORD    dwCreatorType;
;  WORD     wFinderFlags;
;} WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;



.CODE
;Fonction treeFiles permettant de lister les fichiers d'un dossier récursivement à partir d'un dossier fourni en paramètre
treeFiles PROC

		;Initialisation & sauvegarde de la pile + FindFirstFile
		treeFiles_init:
			push    ebp
			mov     ebp, esp
			sub     esp, 4               ; Déclaration du handle

			;Définition de la fonction FindFirstFile (documentation)
			;FindFirstFileA(LPCSTR lpFileName,LPWIN32_FIND_DATAA lpFindFileData);
			push    offset datafiles 		 ; Paramètre structure pour la fonction FindFirstFile
			push    [ebp+8]              ; A partir de x32dbg, l'accès à la structure de la pile permet de récupérer le paramètre du dossier courant pour la fonction FindFirstFile (path)
			call    FindFirstFile				 ; Appel de la fonction FindFirstFile ; resultat dans eax

			; Vérification au cas où présence d'erreur
			; On compare la valeur du résultat. Rappel : Le résultat est stocké dans EAX
			cmp     eax, INVALID_HANDLE_VALUE ; if eax = INVALID_HANDLE_VALUE, call GetLastError
			mov     [esp], eax ; Insertion de la valeur de eax en haut de la pile
			je      GetLastError ; renvoi vers la fonction check_error si INVALID_HANDLE_VALUE.



		;Vérification du fichier (correspondance avec "." et "..") ;
		; Important a savoir : initialement, datafiles.cFileName contient la valeur du nom du fichier définie par la fonction FindFirstFile ci-dessus. On rappelera cette fonction pour tous les fichiers. Ainsi, datafiles.cFileName contiendra
		; à la suite du programme, le nom défini par la fonction FindNextFile car cette dernière utilise la même structure initialement remplie par FindFirstFile. On rafraichit la structure à chaque appel de la fonction FindNextFile.
		; Ainsi, la structure datafiles change à chaque appel de la fonction FindNextFile tant qu'il y a des fichiers dans le répertoire analysé.
		treeFiles_checkFiles:
			;Test si le nomdufichier correspond avec "."
			;int strncmp(const char *string1,const char *string2,size_t count)

			push    1 ; third argument : size
			push    offset datafiles.cFileName ; second argument.
			push    offset strDot ; first argument (".")
			call    crt_strncmp
			;crt_strncmp renvoie 0 dans eax si les deux fichiers sont égaux.

			add     esp, 12 ;Restructuration de la pile (chaque argument (les 3 présents ci-dessus) prend 4 octets soit 4x3 = 12 octets pour bien replacer la pile)
			cmp     eax, 0 ; On compare le résultat de la fonction crt_strncmp avec 0 (ce qui signifie que les deux sont égaux)
			je      treeFiles_nextFile ; Si égal, tout s'est bien passé, on passe au fichier suivant via la fonction treeFiles_nextFile


			;Sinon (eax =1), on teste si le nomdufichier correspond avec ".."
			;int strncmp(const char *string1,const char *string2,size_t count)
			push    1 ; third argument : size
			push    offset datafiles.cFileName ; second argument
			push    offset strDoubleDot ; first argument ("..")
			call    crt_strncmp ;

			add     esp, 12 ; Restructuration de la pile
			cmp     eax, 0 ; On compare le résultat de la fonction compare string avec 0 (ce qui signifie que les deux sont égaux)
			je      treeFiles_nextFile ; Si égal, tout s'est bien passé, on passe au fichier suivant
			;Si le fichier ne correspond ni à ".", ni à "..", le programme continue ci-dessous.



		;Une fois les vérifications faites, on affiche chaque fichier en fonction de son type
		;Une gestion de la tabulation est faîte pour différencier un dossier d'un fichier.
		;On initialise une boucle for avec une variable i qui s'incrémente tant que le i est inférieur au niveau soit l'équivalent en c : for(i=0; i<niveauDossier; i++)
		;Définition de la boucle
				sub     esp, 4 ; On alloue l'espace nécessaire pour i
        mov     dword ptr [esp], 0 ; On initialise l'adresse du haut de la pile à 0 (correspondant à i = 0)
		;On applique ensuite la récursion sur trois fonctionnalités : la tabulation, l'affichage et la vérification si fichier traité est un dossier

		treeFiles_tabulationDossier:
			mov     edx, offset niveauDossier ; Par défaut, le niveau est à 0 (correspondant au 'root' du chemin choisi, ici ./*)
			mov     eax, [esp] ; On déplace l'adresse du haut de la pile dans eax
			cmp     [edx], eax ; On compare l'adresse du haut de la pile avec l'adresse edx, précédemment défini. Plus concrétement, on compare niveauDossier avec le niveau que l'on atteint avec la récursivité.
			je      treeFiles_corpsFunction ; Si c'est égal, on passe à la prochaine étape qui est l'affichage du fichier, au début du programme on ne tabule donc plus car nous sommes au même niveau

			; Si c'est différent, on print un tab, cela signifie qu'on est à l'intérieur d'un dossier, on affiche donc une tabulation juste avant d'afficher le nom du fichier.
			; Cela permet donc une structuration récursive efficace sans retour à la ligne entre chaque print
			push    offset tabulation ; On pousse le contenu de tabulation (soit 2 espaces), correspondant à un TAB en haut de la pile
			call    crt_printf ; On l'affiche dans le terminal.

			add     esp, 4 ; On restructure la stack
			inc     dword ptr [esp] ; On incrémente la valeur de l'adresse d'esp puis on recommence la fonction de tabulation tant que
			jmp     treeFiles_tabulationDossier

		treeFiles_corpsFunction:

			; 1) On affiche le nom du fichier traité
			push    offset datafiles.cFileName
			push    offset file
			call    crt_printf
			add     esp, 8 ; On restructure la stack une fois le print effectué (à l'adresse et la valeur définie ligne 119)


			; 2) On vérifie si le fichier traité est un dossier
			mov     eax, offset datafiles.dwFileAttributes
			cmp     byte ptr[eax], FILE_ATTRIBUTE_DIRECTORY ;rappel issu de x32dbg : [cmp byte ptr eax,10]
			;Si c'est un dossier : eax == FILE_ATTRIBUTE_DIRECTORY

			;Si si c'est un fichier, alors on passe au fichier suivant
			jne     treeFiles_nextFile
			;Sinon, si c'est un dossier on push son nom en haut de la pile et on appelle la fonction SetCurrentDirectory qui permet de définir le nouveau dossier courant
			;Documentation de la fonction SetCurrentDirectory : BOOL SetCurrentDirectory(LPCTSTR lpPathName);
			push    offset datafiles.cFileName ; first arg : lpPathName
			call    SetCurrentDirectory ; appel de la fonction


			; 3) On compare la valeur retournée par la fonction SetCurrentDirectory avec 0 pour déterminer une erreur
			cmp     eax, 0
			;Si c'est OK, la fonction renvoie 1
			;Ainsi, si la fonction n'a pas marché que le datafiles.cFileName ne peut pas être défini comme dossier courent
			;Alors, on passe au fichier suivant
			je      treeFiles_nextFile
			;		Sinon, on incrémente le niveauDossier en passant par le registre EDX. On rentre alors dans un sous-dossier, le niveau change
			mov     edx, offset niveauDossier
			inc     dword ptr [edx] ; ici on incrémente le pointeur, c'est donc la valeur de niveauDossier qui va changer

			; 		Puis on applique la récursivité en rapellant la fonction avec le dossier défini en paramètre de la fonction
			; 		Et on boucle tant qu'il y a des fichiers. La sortie de la boucle se situe à la comparaison avec ERROR_NO_MORE_FILES de la fonction treeFiles_nextFile (ligne 190)
			push    offset CurrentDir
			call    treeFiles



		;Recherche des fichiers suivants :
		treeFiles_nextFile:
			push    offset datafiles ; Second argument ; C'est ici qu'on rappelle la structure initialement remplie par la fonction FindFirstFile, et ce, récursivement.
			push    [ebp-4] ; First argument : Définition du handle nécessaire à la fonction
			call    FindNextFile ; Fonction FindNextFileA ; resultat dans eax

			; Verification si présence d'erreur dans le handle
			cmp     eax, 0 ; FindNextFile renvoie un "binaire" 0 ou 1 dans eax selon le bon fonctionnement
						   ; de la fonction. 1 signifie que l'opération s'est bien passé
						   ; Les informations de la fonction sont stockés dans la structure
			jne     treeFiles_checkNamesNext ; Si il n'y a pas d'erreur, on passe au fichier suivant
			call    GetLastError ; Sinon on renvoie l'erreur correspondante

			; Ensuite, si il n'y a plus de fichier dans le dossier on continue, sinon on saute à l'étape finale
			cmp     eax, ERROR_NO_MORE_FILES
			je      treeFiles_filesEnd ; Si plus de fichier dans le dossier, on passe à l'étape finale


		;Pour chaque nouveau fichier suivant, on teste si c'est un deux dossier "." ou ".."
		treeFiles_checkNamesNext:
			nop ; Incrémentation du EIP pour faciliter le debug dans x32dbg lors du parcours étape par étape
			jmp treeFiles_checkFiles ; On test le fichier pour savoir si il correspond



		; On arrive dans cette fonction quand il n'y a plus de fichier dans le dossier courant :
		; à la fin de cette fonction, la récursivité s'applique avec tous les résultats précédents
		treeFiles_filesEnd:
			;On remonte le dossier courant en poussant ".." et en l'appellant dans la fonction SetCurrentDirectory
			push    offset strDoubleDot
			call    SetCurrentDirectory

			;Une fois remonté, il ne faut pas oublier de décrémenter le niveau de notre dossier. On effectue la même opération
			; que les lignes (166 & 167) en décrementant le niveau à l'inverse de l'incrémenter
			mov     edx, offset niveauDossier
			dec     dword ptr [edx]
			;On restructure la pile
			add     esp, 4
			;On quitte proprement la fonction
			leave
				ret

treeFiles ENDP



start:
		;Un petit peu de décoration
		push 	offset strnull
		push 	offset strIntro
		;Indication du dossier courant
		push 	offset CurrentDir
		push 	offset strIndicationDossierCourant
		call    crt_printf

		;Appel de la fonction treeFiles avec le chemin CurrentDir initial en paramètre
    push    offset CurrentDir
    call    treeFiles

		;Un petit peu d'espace
		push	offset strnull
		call	crt_printf

		;Un petit peu de décoration
		push	offset strOutro
		call	crt_printf


    ;Et on quitte enfin.
    push    offset strCommand
    call    crt_system
    mov     eax, 0
		invoke  ExitProcess,eax

end start
