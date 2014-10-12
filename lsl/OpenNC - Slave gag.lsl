////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenNC - Slave Gag                                //
//                                 version 3.980                                  //
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
string g_szLockCmd="gLock"; // message for setting lock on or off
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

string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szHideCmd="Gag"; // Comand for Blindfold to hide
integer g_nHidden=FALSE;
list TextureElements;
list ColorElements;
list textures;
list colorsettings;
list g_lAlphaSettings;
string g_sIgnore = "nohide";

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
string g_sLockPrimName="Lock"; // Description for lock elements to recognize them //EB //SA: to be removed eventually (kept for compatibility)
string g_sOpenLockPrimName="Lock"; // Prim description of elements that should be shown when unlocked
string g_sClosedLockPrimName="ClosedLock"; // Prim description of elements that should be shown when locked
list g_lClosedLockElements; //to store the locks prim to hide or show //EB
list g_lOpenLockElements; //to store the locks prim to hide or show //EB
string sAlpha;//Alpha se

string gAnim = "express_open_mouth";// The animation to use to keep the mouth open.
float gOpenRate = 0.2;
integer gTypeCounter = 0;// Counts amount of time between timer bursts so the typewatcher isn't annoyingly frequent.
integer gInserted = FALSE;
integer gDroolRate = 3;

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
        return FALSE;// llOwnerSay("error: this script doesn't work for non-linked objects");
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
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size]);//because we don't really want to move the root prim as it moves the whole object
            else
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size, PRIM_POSITION, new_pos]);
        }
    }
}
//end of size adjust

SendCmd( string szSendTo, string szCmd, key keyID ) //this is not the same format as SendCmd1
{
    llRegionSay(g_nCmdChannel, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

SendCmd1( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)g_keyWearer,3,8)) + g_nCmdChannelOffset;
    if (chan>0)
        chan=chan*(-1);
    if (chan > -10000)
        chan -= 30000;
    return chan;
}

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

integer particleDrool(integer active)
{
    if (active == TRUE)    
    {    
        llParticleSystem([PSYS_PART_FLAGS,PSYS_PART_FOLLOW_VELOCITY_MASK|PSYS_PART_INTERP_SCALE_MASK,
                        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
                        PSYS_PART_START_COLOR, <1.0,1.0,1.0>,
                        PSYS_PART_START_ALPHA, 1.00,
                        PSYS_PART_END_COLOR, <1.0,1.0,1.0>,
                        PSYS_PART_END_ALPHA, 1.0,
                        PSYS_PART_START_SCALE, <0.05,0.05,0.0>,
                        PSYS_PART_END_SCALE, <0.02,0.5,0.0>,
                        PSYS_PART_MAX_AGE, 3.0,
                        PSYS_SRC_ACCEL, <0,0,-0.3>,
                        PSYS_SRC_TEXTURE, "974f1934-02e7-9a84-69ac-a99a2157553c",
                        PSYS_SRC_BURST_RATE, gDroolRate,
                        PSYS_SRC_ANGLE_BEGIN, 0.0,
                        PSYS_SRC_ANGLE_END, 3.14,
                        PSYS_SRC_BURST_PART_COUNT, 1,
                        PSYS_SRC_BURST_SPEED_MAX, 0.0,
                        PSYS_SRC_BURST_SPEED_MIN, 0.0,
                        PSYS_SRC_BURST_RADIUS, 0.01,
                        PSYS_SRC_MAX_AGE, 0.0
                        ]);       
    }
    else
    {
        llParticleSystem([PSYS_PART_FLAGS,PSYS_PART_FOLLOW_VELOCITY_MASK|PSYS_PART_INTERP_SCALE_MASK,PSYS_SRC_PATTERN,PSYS_SRC_PATTERN_EXPLODE,PSYS_PART_START_COLOR,<0.00000, 0.00000, 0.00000>,PSYS_PART_START_ALPHA,0.000000,PSYS_PART_START_SCALE,<0.000, 0.000, 0.00000>,PSYS_PART_END_SCALE,<0.0000, 0.0000, 0.00000>,PSYS_PART_MAX_AGE,0.000000,PSYS_SRC_ACCEL,<0.00000, 0.00000, 0.0000>,PSYS_SRC_BURST_PART_COUNT,0,PSYS_SRC_BURST_RATE,0.0,PSYS_SRC_BURST_SPEED_MIN,0.000000,PSYS_SRC_BURST_SPEED_MAX,0.000000]);        
    }
    return TRUE;
}

integer toggleAnim()
{
    llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
    return TRUE;
}

SetLocking()
{
    if (g_nLocked)
    {// lock or unlock cuff as needed in RLV
        if (!g_nLockedState)
            g_nLockedState=TRUE;
        llOwnerSay("@detach=n");
    }
    else
    {
        if (g_nLockedState)
            g_nLockedState=FALSE;
        llOwnerSay("@detach=y");
    }
    SetLockElementAlpha();
}

BuildLockElementList()//EB
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;

    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        // read description
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        // check inf name is lock name
        if (llList2String(lParams, 0)==g_sLockPrimName || llList2String(lParams, 0)==g_sClosedLockPrimName)
        {
            // if so store the number of the prim
            g_lClosedLockElements += [n];
        }
        else if (llList2String(lParams, 0)==g_sOpenLockPrimName) 
        {
            // if so store the number of the prim
            g_lOpenLockElements += [n];
        }
    }
}

SetLockElementAlpha() //EB
{
    if (sAlpha == "0.") return ; // ***** if blindfold is hide, don't do anything 
    //loop through stored links, setting alpha if element type is lock
    integer n;
    //float fAlpha;
    //if (g_iLocked) fAlpha = 1.0; else fAlpha = 0.0; //Let's just use g_iLocked!
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,n), !g_nLockedState, ALL_SIDES);
    }
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,n), g_nLockedState, ALL_SIDES);
    }
}

string GetCuffName()
{
    return llList2String(lstCuffNames,llGetAttached());
}

string szStripSpaces (string szStr)
{
    return llDumpList2String(llParseString2List(szStr, [" "], []), "");
}

string ElementTextureType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["notexture"]) || desc == "" || desc == " " || desc == "(No Description)")
        return "notexture";
    else
        return llList2String(llParseString2List(desc, ["~"], []), 0);
}

BuildTextureList()
{ //loop through non-root prims, build element list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementTextureType(n);
        if (!(~llListFindList(TextureElements, [element])) && element != "notexture")
            TextureElements += [element];
    }
}

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
                llSetLinkTexture(n, tex, ALL_SIDES); //set link to new texture
        }
        //change the textures list entry for the current element
        integer index;
        index = llListFindList(textures, [element]);
        if (index == -1)
            textures += [element, tex];
        else
            textures = llListReplaceList(textures, [tex], index + 1, index + 1);
    }
}

string ElementColorType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to 
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["nocolor"]) || desc == "" || desc == " " || desc == "(No Description)")
        return "nocolor";
    else
        return llList2String(params, 0);
}

BuildColorElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementColorType(n);
        if (!(~llListFindList(ColorElements, [element])) && element != "nocolor")
            ColorElements += [element];
    }
}

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
                llSetLinkColor(n, color, ALL_SIDES);//set link to new color
        }
        //change the colorsettings list entry for the current element
        integer index = llListFindList(colorsettings, [element]);
        if (index == -1)
            colorsettings += [element, color];
        else
            colorsettings = llListReplaceList(colorsettings, [color], index + 1, index + 1);
    }
}

integer IsAllowed( key keyID )
{
    integer nAllow = FALSE;

    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;
    return nAllow;
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
            g_szReceiver = llList2String(lstParsed,1);// cap and store the receiver
            if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )// we are the receiver
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
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    lstParsed = [];
}

ParseSingleCmd( key keyID, string szMsg )
{
    LM_CUFF_CMD(szMsg, keyID);
}

LM_CUFF_CMD(string szMsg, key id)
{// message for cuff received;
    // or info about RLV to be used
    if (nStartsWith(szMsg,g_szLockCmd))
    {// it is a lock commans
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        if (llList2String(lstCmdList,1)=="on")
            g_nLocked=TRUE;
        else
            g_nLocked=FALSE;
        // Update Cuff lock status
        SetLocking();
    }
    else if (szMsg == "rlvon")
    {// RLV got activated
        g_nUseRLV=TRUE;
        SetLocking();// Update Cuff lock status
    }
    else if (szMsg == "rlvoff")
    {// RLV got deactivated
        g_nUseRLV=FALSE;
        SetLocking();// Update Cuff lock status
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
            gInserted = FALSE;
           if(llGetAttached()) toggleAnim();

            particleDrool(FALSE);
        }
        else
        {
            SetAllElementsAlpha (1.0);
            gInserted = TRUE;
            if(llGetAttached()) toggleAnim();
            
            if (gDroolRate > 0)
                particleDrool(TRUE);
            else
                particleDrool(FALSE); 
        }
    }
        else if (nStartsWith(szMsg, "gDrool"))
    { // a change of colors has occured, make sure the cuff try to set identiccal to the collar
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        // set the texture
        gDroolRate = llList2Integer(lstCmdList,1);
        if (gDroolRate > 0)
            particleDrool(TRUE);
        else
            particleDrool(FALSE);
    }
}

SetAllElementsAlpha(float fAlpha)
{//loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    sAlpha = Float2String(fAlpha);
    for (n = 2; n <= iLinkCount; n++)
    {
        string sElement = ElementType(n);
        llSetLinkAlpha(n, fAlpha, ALL_SIDES);
        //update element in list of settings
        integer iIndex = llListFindList(g_lAlphaSettings, [sElement]);
        if (iIndex == -1)
            g_lAlphaSettings += [sElement, sAlpha];
        else
            g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [sAlpha], iIndex + 1, iIndex + 1);
    }
    SetLockElementAlpha();//reset lock to right state
}
string Float2String(float in)
{
    string out = (string)in;
    integer i = llSubStringIndex(out, ".");
    while (~i && llStringLength(llGetSubString(out, i + 2, -1)) && llGetSubString(out, -1, -1) == "0")
        out = llGetSubString(out, 0, -2);
    return out;
}

string ElementType(integer linkiNumber)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(linkiNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to  not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, [g_sIgnore])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
        return g_sIgnore;
    else
        return llList2String(lParams, 0);
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
    BuildTextureList(); //build list of parts we can texture
    BuildColorElementList(); //built list of parts we can color
    SendCmd("rlac",g_szInfoRequest,g_keyWearer); // request infos from main cuff
    SetLocking(); // and set all existing lockstates now
    //resize
    llListenRemove(handle);
    menuChan = 50000 + (integer)llFrand(50000.00);
    handle = llListen(menuChan,"",llGetOwner(),"");
    
    BuildLockElementList();
    gInserted = FALSE;
    if(llGetAttached()) toggleAnim();
    particleDrool(FALSE);
    
}

default
{
    state_entry()
    {
        Init();
        if (scanLinkset())
        { // llOwnerSay("resizer script ready");
        }
    }
    
    attach(key attached)
    {
        if (attached != NULL_KEY)
        {
            toggleAnim();
        }
        else
        {
            gInserted = FALSE;
            toggleAnim();      
        }
    }
    
    run_time_permissions(integer perms)
    {
        if(perms & (PERMISSION_TRIGGER_ANIMATION))
        {
            if (gInserted == TRUE)
            {
                // Start timer which keeps the openmouth anim running.
                llSetTimerEvent(gOpenRate);
            }
            else
            {
                // Stop the openmouth.
                llSetTimerEvent(0.0);
                // Make the wearer smile when their gag is removed.
                llStartAnimation("express_toothsmile");
            }
        }
    }

    on_rez(integer param)
    {
        particleDrool(FALSE);
        if (llGetAttached() == 0) // If not attached then
        {
            llResetScript();
            return;
        }
        
        if (g_keyWearer == llGetOwner())
        {
            Init();// we keep loosing who we are so main cuff won't hear us
            if (g_nLockedState)
                llOwnerSay("@detach=n");
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
            llDialog(llGetOwner(),"Select if you want to Resize this item or the main Cuff Menu ",["Resizer","Cuff Menu"],menuChan);
        // else just ask for main cuff menu
        else { SendCmd1("rlac", "cmenu=on="+(string)llDetectedKey(0), llDetectedKey(0));}
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);
        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel+ 1 )
        {
            if ( IsAllowed(keyID) )
            {
                    string szCmd = CheckCmd( keyID, szMsg );
                    if ( g_nCmdType == CMD_MODULE )
                        ParseCmdString(keyID, szCmd);
            }
        } 
        else if (keyID == llGetOwner())
        {
            if (szMsg == "Cuff Menu")
                SendCmd1("rlac", "cmenu=on="+(string)keyID, keyID);
            else if (szMsg == "Resizer")
                makeMenu();
            else
            {
                if (szMsg == "RESTORE")
                    cur_scale = 1.0;
                else if (szMsg == "MIN SIZE")
                    cur_scale = min_scale;
                else if (szMsg == "MAX SIZE")
                    cur_scale = max_scale;
                else
                    cur_scale += (float)szMsg;
                //check that the scale doesn't go beyond the bounds
                if (cur_scale > max_scale)
                    cur_scale = max_scale;
                if (cur_scale < min_scale)
                    cur_scale = min_scale;
                resizeObject(cur_scale);
                makeMenu();
            }
        }
    }
    
    timer()
    {
        // Run openmouth animation.        
        llStartAnimation(gAnim);
        // If the wearer is typing,
        gTypeCounter++;
        if (gTypeCounter > 10) gTypeCounter = 0;    
    }
    
}