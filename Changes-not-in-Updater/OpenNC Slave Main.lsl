////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenNC - Slave Main                               //
//                                 version 3.960                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
//      Suport for Arms, Legs, Wings, and Tail cuffs and restrictions             //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

string    g_szModToken    = "llac"; // valid token for this module, TBD need to be read more global
key g_keyWearer = NULL_KEY;  // key of the owner/wearer
// Messages to be received
string g_szLockCmd="Lock"; // message for setting lock on or off
string g_szInfoRequest="SendLockInfo"; // request info about RLV and Lock status from main cuff

// name of occ part for requesting info from the master cuff
// NOTE: for products other than cuffs this HAS to be change for the OCC names or the your items will interferre with the cuffs
list lstCuffNames=["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocbelt","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right"];

integer g_nLocked=FALSE; // is the cuff locked
integer g_nUseRLV=FALSE; // should RLV be used
integer g_nLockedState=FALSE; // state submitted to RLV viewer
string g_szIllegalDetach="";
key g_keyFirstOwner;
integer listener;
integer g_nCmdChannel    = -190890;
integer g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for
integer LM_CHAIN_CMD = -551001;
integer LM_CUFF_CUFFPOINTNAME = -551003;
//apperance
string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szHideCmd="HideMe"; // Comand for Cuffs to hide
integer g_nHidden=FALSE;
list TextureElements;
list ColorElements;
list textures;
list colorsettings;
//end
//_slave
string  g_szAllowedCommadToken = "rlac"; // only accept commands from this token adress
list    g_lstModTokens    = []; // valid token for this module
integer    CMD_UNKNOWN        = -1;        // unknown command - don't handle
integer    CMD_CHAT        = 0;        // chat cmd - check what should happen with it
integer    CMD_EXTERNAL    = 1;        // external cmd - check what should happen with it
integer    CMD_MODULE        = 2;        // cmd for this module
integer    g_nCmdType        = CMD_UNKNOWN;
//
// external command syntax
// sender prefix|receiver prefix|command1=value1~command2=value2|UUID to send under
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...
//
string    g_szReceiver    = "";
string    g_szSender        = "";
integer g_nLockGuardChannel = -9119;
//end
//===============================================================================
//= parameters   :    string    szSendTo    prefix of receiving modul
//=                    string    szCmd       message string to send
//=                    key        keyID        key of the AV or object
//=
//= retun        :    none
//=
//= description  :    Sends the command with the prefix and the UUID
//=                    on the command channel
//=
//===============================================================================
SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}
//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)g_keyWearer,3,8)) + g_nCmdChannelOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}
//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================
integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}
//===============================================================================
//= parameters   :    none
//=
//= return        :    none
//=
//= description  :    send locking and RLV info to slave cuffs
//=
//===============================================================================
SetLocking()
{
    if (g_nLocked)
    {// lock or unlock cuff as needed in RLV
        if ((!g_nLockedState && g_nUseRLV) || (g_nLockedState && g_nUseRLV))
        {
            g_nLockedState=TRUE;
            llOwnerSay("@detach=n");
        }
        else if (g_nLockedState && !g_nUseRLV)
        {
            llOwnerSay("@detach=y");
        }
    }
    else
    {
        if (g_nLockedState)
        {
            g_nLockedState=FALSE;
        }
        llOwnerSay("@detach=y");
    }
}
//===============================================================================
//= parameters   :    none
//=
//= return        :    string    szMsg   message string received
//=
//= description  :    read name of cuff from attachment spot
//=
//===============================================================================
string GetCuffName()
{
    return llList2String(lstCuffNames,llGetAttached());
}
//apperance
//===============================================================================
//= parameters   :    string    szStr   String to be stripped
//=
//= return        :    string stStr without spaces
//=
//= description  :    strip the spaces out of a string, needed to as workarounfd in the LM part of OpenCollar - color
//=
//===============================================================================
string szStripSpaces (string szStr)
{
    return llDumpList2String(llParseString2List(szStr, [" "], []), "");
}
// From OpenNC Texture
string ElementTextureType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["notexture"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "notexture";
    }
    else
    {
        return llList2String(llParseString2List(desc, ["~"], []), 0);
    }
}
// From OpenNC Color
string ElementColorType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to 
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["nocolor"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "nocolor";
    }
    else
    {
        return llList2String(params, 0);
    }
}
// From OpenNC Texture
BuildTextureList()
{ //loop through non-root prims, build element list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementTextureType(n);
        if (!(~llListFindList(TextureElements, [element])) && element != "notexture")
        {
            TextureElements += [element];
        }
    }
}
// From OpenNC Texture
SetElementTexture(string element, key tex)
{
    integer i=llListFindList(textures,[element]);
    if ((i==-1)||(llList2Key(textures,i+1)!=tex))
    {
        integer n;
        integer linkcount = llGetNumberOfPrims();
        for (n = 2; n <= linkcount; n++)
        {
            string thiselement = ElementTextureType(n);
            if (thiselement == element)
            { //set link to new texture
                llSetLinkTexture(n, tex, ALL_SIDES);
            }
        }
        //change the textures list entry for the current element
        integer index;
        index = llListFindList(textures, [element]);
        if (index == -1)
        {
            textures += [element, tex];
        }
        else
        {
            textures = llListReplaceList(textures, [tex], index + 1, index + 1);
        }     
    }
}
// From OpenNC Colors
BuildColorElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementColorType(n);
        if (!(~llListFindList(ColorElements, [element])) && element != "nocolor")
        {
            ColorElements += [element];
        }
    }    
}
// From OpenNC Colors
SetElementColor(string element, vector color)
{
    integer i=llListFindList(colorsettings,[element]);
    if ((i==-1)||(llList2Vector(colorsettings,i+1)!=color))
    {
        integer n;
        integer linkcount = llGetNumberOfPrims();
        for (n = 2; n <= linkcount; n++)
        {
            string thiselement = ElementColorType(n);
            if (thiselement == element)
            { //set link to new color
                //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
                llSetLinkColor(n, color, ALL_SIDES);
            }
        }            
        //change the colorsettings list entry for the current element
        integer index = llListFindList(colorsettings, [element]);
        if (index == -1)
        {
            colorsettings += [element, color];
        }
        else
        {
            colorsettings = llListReplaceList(colorsettings, [color], index + 1, index + 1);
        }  
    }
}
// end of OpenNC parts
//end
//_slave
//===============================================================================
//= parameters   : key keyID - the key to check for permission
//=
//= retun        : TRUE if permission is granted
//=
//= description  : checks if the key is allowed to send command to this modul
//=
//===============================================================================
integer IsAllowed( key keyID )
{
    integer nAllow = FALSE;

    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;

    return nAllow;
}
//===============================================================================
//= parameters   :    string    szSendTo    prefix of receiving modul
//=                    string    szCmd       message string to send
//=                    key        keyID        key of the AV or object
//=
//= retun        :    none
//=
//= description  :    Sends the command with the prefix and the UUID
//=                    on the command channel
//=
//===============================================================================
SendCmd1( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}
//===============================================================================
//= parameters   : none
//=
//= retun        : none
//=
//= description  : get owner/wearer key and opens the listeners (std channel + 1)
//=
//===============================================================================
Init()
{
    g_keyWearer = llGetOwner();
    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);
    llListenRemove(g_nCmdHandle);
    g_nCmdHandle = llListen(g_nCmdChannel + 1, "", NULL_KEY, "");
    g_lstModTokens = (list)llList2String(lstCuffNames,llGetAttached()); // get name of the cuff from the attachment point, this is absolutly needed for the system to work, other chain point wil be received via LMs
    g_szModToken=GetCuffName();
    BuildTextureList();
    BuildColorElementList();
    // listen to LockGuard requests
    llListen(g_nLockGuardChannel,"","","");
    // request infos from main cuff
    SendCmd("rlac",g_szInfoRequest,g_keyWearer);
    // and set all now existing lockstates
    SetLocking();

}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :    string    command without prefixes if it has to be handled here
//=
//= description  :    checks if the message includes a valid ext. prefix
//=                    and if it's for this module
//=
//===============================================================================
string CheckCmd( key keyID, string szMsg )
{
    list lstParsed = llParseString2List( szMsg, [ "|" ], [] );
    string szCmd = szMsg;

    // first part should be sender token
    // second part the receiver token
    // third part = command
    if ( llGetListLength(lstParsed) > 2 )
    {
        // check the sender of the command occ,rwc,...
        g_szSender = llList2String(lstParsed,0);
        g_nCmdType = CMD_UNKNOWN;

        if ( g_szSender==g_szAllowedCommadToken ) // only accept command from the master cuff
        {
            g_nCmdType = CMD_EXTERNAL;
            // cap and store the receiver
            g_szReceiver = llList2String(lstParsed,1);
            // we are the receiver
            if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )
            {
                // set cmd return to the rest of the command string
                szCmd = llList2String(lstParsed,2);
                g_nCmdType = CMD_MODULE;
            }
        }
    }
    lstParsed = [];
    return szCmd;
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :
//=
//= description  :    devides the command string into single commands
//=                    delimiter = ~
//=                    single commands are redirected to ParseSingleCmd
//=
//===============================================================================
ParseCmdString( key keyID, string szMsg )
{
    list    lstParsed = llParseString2List( szMsg, [ "~" ], [] );
    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;
    for (i = 0; i < nCnt; i++ )
    {
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    }
    lstParsed = [];
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   single command string
//=
//= retun        :
//=
//= description  :    devides the command string into command & parameter
//=                    delimiter is =
//=
//===============================================================================
ParseSingleCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "=" ], [] );
    string    szCmd    = llList2String(lstParsed,0);
    string    szValue    = llList2String(lstParsed,1);
    if ( szCmd == "chain" )
    {
        if (( llGetListLength(lstParsed) == 4 )||( llGetListLength(lstParsed) == 7 ))
        {
            if ( llGetKey() != keyID )
            llMessageLinked( LINK_SET, LM_CHAIN_CMD, szMsg, llGetKey() );
      }
    }
    else
    {
        LM_CUFF_CMD(szMsg, keyID);
    }

    lstParsed = [];
}

//end
//new
LM_CUFF_CMD(string szMsg, key id)
{// message for cuff received;
    // or info about RLV to be used
    if (nStartsWith(szMsg,g_szLockCmd))
    {// it is a lock commans
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        if (llList2String(lstCmdList,1)=="on")
        {
            g_nLocked=TRUE;
        }
        else
        {
            g_nLocked=FALSE;
        }
        // Update Cuff lock status
        SetLocking();
    }
    else if (szMsg == "rlvon")
    {// RLV got activated
        g_nUseRLV=TRUE;
        // Update Cuff lock status
        SetLocking();
    }
    else if (szMsg == "rlvoff")
    {// RLV got deactivated
        g_nUseRLV=FALSE;
        // Update Cuff lock status
        SetLocking();
    }
    //apperance
    else if (nStartsWith(szMsg,g_szColorChangeCmd))
    { // a change of colors has occured, make sure the cuff try to set identiccal to the collar
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        // set the color, uses StripSpace fix for colrs just in case
        SetElementColor(llList2String(lstCmdList,1),(vector)szStripSpaces(llList2String(lstCmdList,2)));   
    }
    else if (nStartsWith(szMsg,g_szTextureChangeCmd))
    { // a change of colors has occured, make sure the cuff try to set identiccal to the collar
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        // set the texture
        SetElementTexture(llList2String(lstCmdList,1),szStripSpaces(llList2String(lstCmdList,2)));   
    }
    else if (nStartsWith(szMsg,g_szHideCmd))
    { // a change of colors has occured, make sure the cuff try to set identiccal to the collar
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        g_nHidden= llList2Integer(lstCmdList,1);
        if (g_nHidden)
        {
            llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
        }
        else
        {
            llSetLinkAlpha(LINK_SET,1.0,ALL_SIDES);
        }
    }
    //end
}
//end

default
{
    on_rez(integer param)
    {
        if (g_nLockedState)
        {
            llOwnerSay("@detach=n");
        }
        llResetScript();
    }
    touch_start(integer nCnt)
    {   // call menu from maincuff
        // Cleo: Added another parameter of clicker to the message
        SendCmd1("rlac", "cmenu=on="+(string)llDetectedKey(0), llDetectedKey(0));
    }

    state_entry()
    {  
        Init();
    }
    
    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if( nNum == LM_CUFF_CUFFPOINTNAME )
        {
            if (llListFindList(g_lstModTokens,[szMsg])==-1)
            {
                g_lstModTokens+=[szMsg];
            }
        }
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);
        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel+ 1 )
        {
            if ( IsAllowed(keyID) )
            {
                if (llGetSubString(szMsg,0,8)=="lockguard")
                {
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                }
                else
                {
                    // check if external or maybe for this module
                    string szCmd = CheckCmd( keyID, szMsg );
                    if ( g_nCmdType == CMD_MODULE )
                    {
                        ParseCmdString(keyID, szCmd);
                    }
                }
            }
        } 
        else if ( nChannel == g_nLockGuardChannel)
        // LG message received, forward it to the other prims
        {
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,NULL_KEY);
        }
    }
}