////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenNC - Slave Main                               //
//                                 version 3.961                                  //
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
list g_lAlphaSettings;
string g_sIgnore = "nohide";
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

//size adust
float MIN_DIMENSION=0.001; // the minimum scale of a prim allowed, in any dimension
float MAX_DIMENSION=1.0; // the maximum scale of a prim allowed, in any dimension
float max_scale;
float min_scale;
float   cur_scale = 1.0;
integer handle;
integer menuChan;
float min_original_scale=10.0; // minimum x/y/z component of the scales in the linkset
float max_original_scale=0.0; // minimum x/y/z component of the scales in the linkset
list link_scales = [];
list link_positions = [];
 
makeMenu()
{
    llDialog(llGetOwner(),"Max scale: "+(string)max_scale+"\nMin scale: "+(string)min_scale+"\n \nCurrent scale: "+
        (string)cur_scale,["-0.01","-0.05","MIN  SIZE","+0.01","+0.05","MAX  SIZE","-0.10","-0.25","RESTORE","+0.10","+0.25"],menuChan);
}
 
integer scanLinkset()
{
    integer link_qty = llGetNumberOfPrims();
    integer link_idx;
    vector link_pos;
    vector link_scale;
    //script made specifically for linksets, not for single prims
    if (link_qty > 1)
    {
        //link numbering in linksets starts with 1
        for (link_idx=1; link_idx <= link_qty; link_idx++)
        {
            link_pos=llList2Vector(llGetLinkPrimitiveParams(link_idx,[PRIM_POSITION]),0);
            link_scale=llList2Vector(llGetLinkPrimitiveParams(link_idx,[PRIM_SIZE]),0);
            // determine the minimum and maximum prim scales in the linkset,
            // so that rescaling doesn't fail due to prim scale limitations
            if(link_scale.x<min_original_scale) min_original_scale=link_scale.x;
            else if(link_scale.x>max_original_scale) max_original_scale=link_scale.x;
            if(link_scale.y<min_original_scale) min_original_scale=link_scale.y;
            else if(link_scale.y>max_original_scale) max_original_scale=link_scale.y;
            if(link_scale.z<min_original_scale) min_original_scale=link_scale.z;
            else if(link_scale.z>max_original_scale) max_original_scale=link_scale.z;
            link_scales    += [link_scale];
            link_positions += [(link_pos-llGetRootPosition())/llGetRootRotation()];
        }
    }
    else
    {
//        llOwnerSay("error: this script doesn't work for non-linked objects");
        return FALSE;
    }
    max_scale = MAX_DIMENSION/max_original_scale;
    min_scale = MIN_DIMENSION/min_original_scale;
    return TRUE;
}
 
resizeObject(float scale)
{
    integer link_qty = llGetNumberOfPrims();
    integer link_idx;
    vector new_size;
    vector new_pos;
    if (link_qty > 1)
    {
        //link numbering in linksets starts with 1
        for (link_idx=1; link_idx <= link_qty; link_idx++)
        {
            new_size   = scale * llList2Vector(link_scales, link_idx-1);
            new_pos    = scale * llList2Vector(link_positions, link_idx-1);
 
            if (link_idx == 1)
            {
                //because we don't really want to move the root prim as it moves the whole object
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size]);
            }
            else
            {
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size, PRIM_POSITION, new_pos]);
            }
        }
    }
}
//end of size adjust


SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

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

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

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

string GetCuffName()
{
    return llList2String(lstCuffNames,llGetAttached());
}
//apperance

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

integer IsAllowed( key keyID )
{
    integer nAllow = FALSE;

    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;

    return nAllow;
}

SendCmd1( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

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
    //resize
    llListenRemove(handle);
    menuChan = 50000 + (integer)llFrand(50000.00);
    handle = llListen(menuChan,"",llGetOwner(),"");

}

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
            SetAllElementsAlpha (0.0);
        }
        else
        {
            SetAllElementsAlpha (1.0);
        }
    }
    //end
}
//end
SetAllElementsAlpha(float fAlpha)
{//loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    string sAlpha = Float2String(fAlpha);
    for (n = 2; n <= iLinkCount; n++)
    {
        string sElement = ElementType(n);
            llSetLinkAlpha(n, fAlpha, ALL_SIDES);
            //update element in list of settings
            integer iIndex = llListFindList(g_lAlphaSettings, [sElement]);
            if (iIndex == -1)
            {
                g_lAlphaSettings += [sElement, sAlpha];
            }
            else
            {
                g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [sAlpha], iIndex + 1, iIndex + 1);
            }
    }
}
string Float2String(float in)
{
    string out = (string)in;
    integer i = llSubStringIndex(out, ".");
    while (~i && llStringLength(llGetSubString(out, i + 2, -1)) && llGetSubString(out, -1, -1) == "0")
    {
        out = llGetSubString(out, 0, -2);
    }
    return out;
}
string ElementType(integer linkiNumber)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(linkiNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to  not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, [g_sIgnore])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
    {
        return g_sIgnore;
    }
    else
    {
        return llList2String(lParams, 0);
    }
}

default
{
    on_rez(integer param)
    {
        if (llGetAttached() == 0) // If not attached then
        {
            llResetScript();
            return;
        }
        
        if (g_keyWearer == llGetOwner())
        {
            if (g_nLockedState)
            {
                Init();// we keep loosing who we are so main cuff won't hear us
                llOwnerSay("@detach=n");
            }       
        }
        else llResetScript();
    }
    
    touch_start(integer nCnt)
    {
        key id = llDetectedKey(0);
        if ((llGetAttached() == 0)&& (id==g_keyWearer)) // If not attached then wake up update script then do nothing
        {
            llSetScriptState("OpenNC - update",TRUE);
            return;
        }
        
        if (llDetectedKey(0) == llGetOwner())// if we are wearer then allow to resize
        {
            llDialog(llGetOwner(),"Select if you want to Resize this item or the main Cuff Menu ",["Resizer","Cuff Menu"],menuChan);
        }
        else { SendCmd1("rlac", "cmenu=on="+(string)llDetectedKey(0), llDetectedKey(0));}
    }

    state_entry()
    {
        if (scanLinkset()) { // llOwnerSay("resizer script ready");
        }
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
                { // check if external or maybe for this module
                    string szCmd = CheckCmd( keyID, szMsg );
                    if ( g_nCmdType == CMD_MODULE )
                    {
                        ParseCmdString(keyID, szCmd);
                    }
                }
            }
        } 
        else if ( nChannel == g_nLockGuardChannel)
        {// LG message received, forward it to the other prims
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,NULL_KEY);
        }
        else if (keyID == llGetOwner())
        {
            if (szMsg == "Cuff Menu")
            {
                SendCmd1("rlac", "cmenu=on="+(string)keyID, keyID);
            }
            else if (szMsg == "Resizer")
            {
                makeMenu();
            }
            else
            {
                if (szMsg == "RESTORE")
                {
                    cur_scale = 1.0;
                }
                else if (szMsg == "MIN SIZE")
                {
                    cur_scale = min_scale;
                }
                else if (szMsg == "MAX SIZE")
                {
                    cur_scale = max_scale;
                }          
                else
                {
                    cur_scale += (float)szMsg;
                }
                //check that the scale doesn't go beyond the bounds
                if (cur_scale > max_scale)
                { 
                    cur_scale = max_scale;
                }
                if (cur_scale < min_scale)
                {
                    cur_scale = min_scale;
                }
                resizeObject(cur_scale);
                makeMenu();
            }
        }
    }
}