"""Offline rendering of recorded addon UI calls; not an in-game screenshot.

Requires the test Lua runtime and Pillow. Native textures are read from
.work/art-reference. Fonts, backdrop tiling, portraits and cooldown sweeps are
approximations. Geometry, spell crops, anchors and strings come from addon Lua.
"""
import math
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".work/python-packages"))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

ART = ROOT / ".work/art-reference"
SCALE = 1.8
SCENE_W, SCENE_H = 850, 680


def capture():
    global SCENE_H
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().RENDER_QUADRANTS = "--quadrants" in sys.argv
    lua.globals().RENDER_SHIFT = "--shift" in sys.argv
    lua.globals().RENDER_MENU_OPEN = "--menu-open" in sys.argv
    lua.globals().RENDER_PROMPT = "--prompt" in sys.argv
    lua.globals().RENDER_PREDICTIONS = "--predictions" in sys.argv
    lua.globals().RENDER_HOVER = "--hover" in sys.argv
    lua.globals().RENDER_HISTORY = "--history" in sys.argv
    lua.globals().RENDER_CLEANSES = "--cleanses" in sys.argv
    lua.globals().RENDER_PARITY = "--parity" in sys.argv
    lua.execute(r'''
state = assert(loadfile("tests/wow_ui_fake.lua"))()()
state.subgroupCount=0
PowerBarColor.RAGE={r=1,g=0.12,b=0.12}; PowerBarColor.ENERGY={r=1,g=0.85,b=0.1}
RAID_CLASS_COLORS.DRUID={r=1,g=0.49,b=0.04}; RAID_CLASS_COLORS.ROGUE={r=1,g=0.96,b=0.41}
CLASS_ICON_TCOORDS={WARRIOR={0,.25,0,.25},MAGE={.25,.49609375,0,.25},ROGUE={.49609375,.7421875,0,.25},DRUID={.7421875,.98828125,0,.25}}
local m = state.methods
if RENDER_PREDICTIONS or RENDER_HOVER or RENDER_HISTORY then
    assert(loadfile("tests/prediction_api_fake.lua"))()(state)
    local getFill, setFill = m.GetStatusBarTexture, m.SetStatusBarTexture
    function m:GetStatusBarTexture()
        local fill = getFill(self)
        fill.renderStatusBar = self
        return fill
    end
    function m:SetStatusBarTexture(value)
        setFill(self, value)
        if type(value) == "table" then self.statusTexture = value end
        self:GetStatusBarTexture()
    end
end
if RENDER_HISTORY then assert(loadfile("tests/history_api_fake.lua"))()(state) end
local oldLevel=m.SetFrameLevel
function m:SetFrameLevel(value)
    local delta=value-(self.level or 1)
    oldLevel(self,value)
    local function shift(parent)
        for _,child in ipairs(parent.children or {}) do
            child.level=(child.level or 1)+delta
            shift(child)
        end
    end
    shift(self)
end
local oldPoint, oldClear = m.SetPoint, m.ClearAllPoints
function m:SetPoint(...)
    oldPoint(self, ...)
    self.renderPoints = self.renderPoints or {}
    self.renderPoints[select(1,...)] = {...}
end
function m:ClearAllPoints() oldClear(self); self.renderPoints = {} end
local oldTexture, oldFont = m.CreateTexture, m.CreateFontString
function m:CreateTexture(name, layer, template, sublevel)
    local t = oldTexture(self,name); t.renderLayer=layer; t.renderSublevel=sublevel; return t
end
function m:CreateFontString(name,layer,template)
    local t=oldFont(self,name); t.renderLayer=layer; t.renderTemplate=template; return t
end
local oldNormalFont=m.SetNormalFontObject
function m:SetNormalFontObject(template)
    oldNormalFont(self,template)
    self.renderTemplate=template
end
local originalCreate = CreateFrame
function CreateFrame(kind,name,parent,template)
    local f=originalCreate(kind,name,parent,template)
    f.level=parent and (parent.level+1) or 1
    if template=="UIPanelCloseButton" then f:SetSize(32,32); f:SetText("x") end
    return f
end
ns={}
local function load(name) assert(loadfile("WowfPartyFrames/"..name..".lua"))("WowfPartyFrames",ns) end
load("Bootstrap"); load("Profiles"); load("Assignments")
ns.db=ns.Profiles:Init({controlStyle=RENDER_QUADRANTS and "quadrants" or "buttons"})
local tankPreset=assert(ns.Profiles:Create("Tank"))
ns.Profiles:GetPreset(tankPreset).heals={2050,2052,2061,139}
ns.Profiles:GetPreset(tankPreset).buffs={1243,14752,976}
ns.Profiles:GetPreset(tankPreset).healLayers.shift={139,2061,2052,2050}
ns.Profiles:Create("Melee"); ns.Profiles:Create("Caster")
ns.Assignments:Init(ns.db)
local spells={
 [2050]={"Heal","Rank 2","Spell_Holy_Heal"}, [2052]={"Heal","Rank 4","Spell_Holy_Heal"},
 [2061]={"Flash Heal","Rank 4","Spell_Holy_FlashHeal"}, [139]={"Renew","Rank 5","Spell_Holy_Renew"},
 [1243]={"Fortitude","Rank 4","Spell_Holy_WordFortitude"},
 [14752]={"Divine Spirit","Rank 2","Spell_Holy_DivineSpirit"},
 [976]={"Shadow Protection","Rank 2","Spell_Shadow_AntiShadow"}}
ns.Spells={Get=function(_,id) local s=spells[id]; if s then return {id=id,name=s[1],rank=s[2],icon="Interface\\Icons\\"..s[3]} end end}
ns.Rates={SetUnits=function() end,Get=function() return 50,45,5,"available" end}
ns.Auras={GetDebuffs=function() return {},true end,GetAssignedBuff=function() return {state="unknown"} end,Paint=function() end}
if RENDER_HOVER then
    -- Explicit test-only descriptions exercise the real estimate parser. These
    -- invented amounts are layout fixtures, not claims about spell ranks.
    local descriptions={
        [2050]="Heals a friendly target for 650 to 800.",
        [139]="Heals the target for 500 over 15 sec.",
        [2061]="Shields the target, absorbing 700 damage. Lasts 30 sec.",
        [2052]="Heals a friendly target for 200 to 250 and another 500 over 15 sec.",
    }
    C_Spell=C_Spell or {}
    C_Spell.GetSpellDescription=function(id) return descriptions[id] end
    GetLocale=function() return "enUS" end
    load("SpellEstimates"); load("HoverPrediction")
end
load("FrameVisuals")
-- The render uses the shipped /wpf test path. --parity only enables the
-- native pet preference; it never replaces preview identity with live units.
GetCVarBool=function(name) return RENDER_PARITY and name=="showPartyPets" end
load("MemberInfo"); load("PreviewData")
load("PartyPresence"); load("PartyStatus"); load("PartyPets"); load("AuraDetails")
if RENDER_CLEANSES then
    -- Public sample actions only: Preview never creates native aura controls
    -- or configures secure casting. Spell art is mapped from saved mock assets.
    ns.Cleanses={GetActions=function() return {
        {key="Magic",spellID=527,types={Magic=true},record={icon="PreviewDispel"}},
        {key="Disease",spellID=528,types={Disease=true},record={icon="PreviewDisease"}},
    } end}
    load("CleanseGeometry"); load("CleanseDisplay")
end
if RENDER_HISTORY then load("HealthHistory") end
if RENDER_PREDICTIONS then load("HealthPrediction") end
load("Frames"); load("Settings"); load("PresetMenus")
UIParent:SetSize(850,680)
ns.Frames:Create()
ns.Frames.anchor:ClearAllPoints(); ns.Frames.anchor:SetPoint("TOPLEFT",UIParent,"TOPLEFT",22,-60)
ns.Frames:TogglePreview()
local p=ns.Frames.preview
ns.Settings:Create(); ns.Settings:SelectPreset(tankPreset); ns.Settings.frame:Show()
ns.Settings.frame:ClearAllPoints(); ns.Settings.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",465,-60)
if RENDER_SHIFT then ns.Settings:SelectHealLayer("shift") end
if RENDER_MENU_OPEN then ns.Settings.frame.selector:GetScript("OnClick")() end
if RENDER_PROMPT then
    local prompt=ns.PresetMenus:CreatePrompt(1,p.cards[1])
    prompt.title:SetText('Assign "Tank" to Thorin?')
    prompt:Show()
end
ns.Visuals:SetPortraitHover(p.cards[1],true)
if RENDER_CLEANSES then
    for _,card in ipairs(p.cards) do ns.Visuals:SetPortraitHover(card,RENDER_HOVER) end
    RENDER_SCENE_H=math.max(680,math.ceil(ns.Frames.anchor:GetHeight()+120))
    UIParent:SetSize(850,RENDER_SCENE_H)
end
for index,card in ipairs(p.cards) do card.renderClass=({"WARRIOR","MAGE","DRUID","ROGUE"})[index] end
if RENDER_HOVER then
    -- Exercise the assigned control in each existing sample. Never rewrite
    -- sample health or spell assignments after the production preview opens.
    for index,card in ipairs(p.cards) do
        local button=card.heals[index]
        assert(ns.HoverPrediction:Show(button,nil,card.previewHealthMax),"Assigned preview heal could not render")
    end
end
-- Health-history and native-prediction samples were painted by TogglePreview
-- and its ordinary refresh path; there are no renderer-only data overrides.
-- Size the capture from actual production preview layout, including pets.
RENDER_SCENE_H=math.max(680,math.ceil(ns.Frames.anchor:GetHeight()+120))
UIParent:SetSize(850,RENDER_SCENE_H)
for index,obj in ipairs(state.objects) do obj.renderID=index end
for _,obj in ipairs(state.objects) do
 if obj.format and obj.formatValues then obj.renderText=string.format(obj.format,unpack(obj.formatValues))
 else obj.renderText=obj.text end
end
''')
    objects = list(lua.globals().state.objects.values())
    if lua.globals().RENDER_SCENE_H is not None:
        SCENE_H = int(lua.globals().RENDER_SCENE_H)
    return objects


def seq(table):
    return list(table.values()) if table is not None else []


def rgba(values, default=(255,255,255,255)):
    if values is None:
        return default
    v = seq(values)
    return tuple(round(max(0,min(1,x))*255) for x in (v+[1,1,1,1])[:4])


def main():
    os.chdir(ROOT)
    objects = capture()
    cache = {}
    def ident(obj): return int(obj.renderID)
    def parent(obj): return obj.parent
    def font(obj):
        size = obj.font[2] if obj.font else (14 if obj.renderTemplate == "GameFontNormalLarge" else 11)
        path = Path("C:/Windows/Fonts/georgia.ttf")
        return ImageFont.truetype(str(path), max(8,round(size*SCALE)))
    def content(obj): return str(obj.renderText or "")
    def fraction(point):
        return (0 if "LEFT" in point else 1 if "RIGHT" in point else .5,
                0 if "TOP" in point else 1 if "BOTTOM" in point else .5)
    def rect(obj):
        key=ident(obj)
        if key in cache: return cache[key]
        if obj.name == "UIParent": return (0,0,SCENE_W,SCENE_H)
        if obj.renderStatusBar is not None:
            bar=obj.renderStatusBar
            x,y,w,h=rect(bar)
            amount=max(0,min(1,(bar.value or 0)/max(1,bar.maximum or 1)))
            box=(x+w*(1-amount) if bar.reverseFill else x,y,w*amount,h)
            cache[key]=box;return box
        par=parent(obj)
        base=rect(par) if par is not None else (0,0,SCENE_W,SCENE_H)
        if obj.allPoints is not None:
            target=obj.allPoints[1]
            box=rect(target) if target is not None and not isinstance(target,bool) else base
            cache[key]=box; return box
        w,h=obj.width,obj.height
        if obj.kind == "FontString":
            bbox=font(obj).getbbox(content(obj)); line=font(obj).getbbox("Hg")
            w=w or (bbox[2]-bbox[0])/SCALE; h=h or (line[3]-line[1]+3)/SCALE
        points=seq(obj.renderPoints)
        constraints=[]
        for p in points:
            args=seq(p); point=args[0]; rem=args[1:]
            target=par; rel=point; dx=dy=0
            if rem and isinstance(rem[0],(int,float)):
                dx=rem[0];dy=rem[1] if len(rem)>1 else 0
            elif rem:
                if rem[0] is not None: target=rem[0]
                if len(rem)>1 and isinstance(rem[1],str): rel=rem[1]; rem=rem[2:]
                else: rem=rem[1:]
                if rem: dx=rem[0]
                if len(rem)>1:dy=rem[1]
            box=rect(target) if target is not None else base
            rx,ry=fraction(rel); fx,fy=fraction(point)
            constraints.append((fx,fy,box[0]+rx*box[2]+dx,box[1]+ry*box[3]-dy))
        if len(constraints)>1:
            a=constraints[0]
            for b in constraints[1:]:
                if w is None and a[0]!=b[0]: w=(b[2]-a[2])/(b[0]-a[0])
                if h is None and a[1]!=b[1]: h=(b[3]-a[3])/(b[1]-a[1])
        w,h=w or 0,h or 0
        x,y=base[:2]
        if constraints:
            a=constraints[0];x,y=a[2]-a[0]*w,a[3]-a[1]*h
        cache[key]=(x,y,w,h);return cache[key]
    def visible(obj):
        if obj.shown is False or obj.alpha==0:return False
        return visible(parent(obj)) if parent(obj) is not None else True
    def alpha(obj): return (obj.alpha or 1)*(alpha(parent(obj)) if parent(obj) is not None else 1)
    def level(obj):
        if obj.kind in ("Texture","FontString","MaskTexture"): return level(parent(obj))
        return obj.level or 1
    layers={"BACKGROUND":0,"BORDER":1,"ARTWORK":2,"OVERLAY":3,"HIGHLIGHT":4}
    def order(obj):
        layer = 1.5 if obj.kind == "StatusBar" else layers.get(obj.renderLayer,0)
        return (level(obj), layer,obj.renderSublevel or 0,ident(obj))
    canvas=Image.new("RGBA",(round(SCENE_W*SCALE),round(SCENE_H*SCALE)))
    draw=ImageDraw.Draw(canvas)
    for y in range(canvas.height):
        t=y/canvas.height;draw.line((0,y,canvas.width,y),fill=(round(35-15*t),round(36-16*t),round(38-16*t),255))
    files={p.stem.lower():p for p in ART.glob("*") if p.suffix.lower()==".png"}
    if "--cleanses" in sys.argv:
        for name, filename in (("previewdispel", "dispel.jpg"), ("previewdisease", "disease.jpg")):
            saved = ROOT / ".work/cleanse-mockup" / filename
            if saved.is_file(): files[name] = saved
    atlas=Image.open(files["ui-classes-circles"]).convert("RGBA") if "ui-classes-circles" in files else None
    classes={"WARRIOR":(0,0),"MAGE":(1,0),"ROGUE":(2,0),"DRUID":(3,0)}
    missing=set()
    approximations=set()
    def badge(name,w,h):
        marks={
            "UI-HUD-UnitFrame-Player-Group-LeaderIcon":("L",(240,193,55)),
            "UI-HUD-UnitFrame-Player-Group-GuideIcon":("G",(240,193,55)),
            "ui-hud-unitframe-player-pvp-allianceicon":("P",(90,165,245)),
            "ui-hud-unitframe-player-pvp-hordeicon":("P",(220,75,55)),
            "UI-LFG-ReadyMark":("+",(90,240,100)),
            "UI-LFG-PendingMark":("?",(240,200,60)),
            "UI-LFG-DeclineMark":("x",(245,80,65)),
            "roleicon-tiny-tank":("T",(120,185,235)),
            "roleicon-tiny-healer":("+",(100,235,120)),
            "roleicon-tiny-dps":("D",(230,150,70)),
            "ui-phasingicon":("S",(180,150,240)),
            "disconnect-icon":("!",(150,150,150)),
            "Raid-Icon-SummonPending":("S",(215,175,245)),
            "Raid-Icon-SummonAccepted":("S",(115,235,150)),
            "Raid-Icon-SummonDeclined":("S",(235,100,100)),
            "voicechat-icon-speaker":("V",(115,225,120)),
            "ability_hunter_pet_bear":("B",(190,150,100)),
            "spell_nature_corrosivebreath":("P",(100,210,90)),
            "spell_nature_nullifydisease":("D",(190,160,85)),
            "spell_shadow_shadowwordpain":("M",(195,105,230)),
            "raid-marker-star":("*",(250,220,60)),
            "raid-marker-moon":("C",(205,210,245)),
        }
        if name not in marks:return None
        approximations.add(name)
        mark,color=marks[name]
        image=Image.new("RGBA",(w,h),(0,0,0,0));d=ImageDraw.Draw(image)
        d.ellipse((1,1,w-2,h-2),fill=(20,20,24,225),outline=color,width=max(1,round(SCALE)))
        d.text((w/2,h/2),mark,font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",max(8,round(h*.72))),anchor="mm",fill=color)
        return image
    for obj in sorted(objects,key=order):
        if not visible(obj) or obj.kind=="MaskTexture" or obj.renderStatusBar is not None:continue
        x,y,w,h=rect(obj)
        if w<=0 or h<=0:continue
        X,Y,W,H=round(x*SCALE),round(y*SCALE),max(1,round(w*SCALE)),max(1,round(h*SCALE))
        tile=None
        if obj.kind=="Texture":
            if obj.SetColorTextureArgs is not None: tile=Image.new("RGBA",(W,H),rgba(obj.SetColorTextureArgs))
            elif obj.atlas in ("RaidFrame-Shield-Overshield", "RaidFrame-Absorb-Overabsorb"):
                # Approximate native glow artwork; its visibility/anchors come
                # from the actual addon and the public preview calculator.
                tile=Image.new("RGBA",(W,H),(0,0,0,0));td=ImageDraw.Draw(tile)
                tint=(125,210,255) if obj.atlas=="RaidFrame-Shield-Overshield" else (215,120,235)
                for px in range(W):
                    opacity=round(185*max(0,1-abs(px-W*.5)/(W*.5)))
                    td.line((px,0,px,H),fill=tint+(opacity,))
            elif obj.atlas and badge(str(obj.atlas),W,H) is not None:
                tile=badge(str(obj.atlas),W,H)
            elif obj.portraitUnit is not None and atlas:
                anc=parent(obj)
                while anc is not None and not anc.renderClass:anc=parent(anc)
                cx,cy=classes.get(anc.renderClass if anc is not None else "WARRIOR",(0,0))
                cell=atlas.width//4;tile=atlas.crop((cx*cell,cy*cell,(cx+1)*cell,(cy+1)*cell)).resize((W,H),Image.Resampling.LANCZOS)
            elif obj.texture:
                texture_path=str(obj.texture).replace("\\","/")
                name=texture_path.split("/")[-1].split(".")[0].lower()
                if name=="ui-raidtargetingicons" and obj.spriteCell:
                    name="raid-marker-moon" if obj.spriteCell[1]==5 else "raid-marker-star"
                path=files.get(name)
                prefix="Interface/AddOns/WowfPartyFrames/Media/"
                if texture_path.startswith(prefix):
                    candidate=(ROOT/"WowfPartyFrames"/"Media"/texture_path[len(prefix):]).resolve()
                    media=(ROOT/"WowfPartyFrames"/"Media").resolve()
                    if candidate.is_relative_to(media) and candidate.is_file(): path=candidate
                if path:
                    tile=Image.open(path).convert("RGBA")
                    coords=seq(obj.SetTexCoordArgs)
                    if len(coords)==4:
                        u1,u2,v1,v2=coords
                        tile=tile.crop((round(min(u1,u2)*tile.width),round(min(v1,v2)*tile.height),round(max(u1,u2)*tile.width),round(max(v1,v2)*tile.height)))
                        if u2<u1: tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                        if v2<v1: tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                    elif len(coords)==8:
                        # WoW gives UL, LL, UR, LR; Pillow expects UL, LL, LR, UR.
                        points=[(coords[i]*tile.width,coords[i+1]*tile.height) for i in range(0,8,2)]
                        quad=tuple(value for i in (0,1,3,2) for value in points[i])
                        tile=tile.transform((W,H),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
                    tile=tile.resize((W,H),Image.Resampling.LANCZOS)
                elif badge(name,W,H) is not None:tile=badge(name,W,H)
                elif "statusbar" in name or "white" in name:tile=Image.new("RGBA",(W,H),(255,255,255,255))
                elif name=="shield-overlay":
                    tile=Image.new("RGBA",(W,H),(0,0,0,0));td=ImageDraw.Draw(tile)
                    for sx in range(-H,W+H,7):td.line((sx,0,sx+H,H),fill=(235,245,255,130),width=1)
                elif "emptyslot" in name:tile=Image.new("RGBA",(W,H),(24,22,19,255))
                else:missing.add(name)
            if tile is not None:
                if obj.SetDesaturatedArgs and obj.SetDesaturatedArgs[1]:
                    saved_alpha=tile.getchannel("A")
                    tile=ImageOps.grayscale(tile).convert("RGBA")
                    tile.putalpha(saved_alpha)
                if obj.SetVertexColorArgs is not None:tile=ImageChops.multiply(tile,Image.new("RGBA",tile.size,rgba(obj.SetVertexColorArgs)))
                masks=seq(obj.AddMaskTextureArgs)
                if masks:
                    mx,my,mw,mh=rect(masks[0]);mask=Image.new("L",(W,H),0)
                    ImageDraw.Draw(mask).ellipse(((mx-x)*SCALE,(my-y)*SCALE,(mx+mw-x)*SCALE,(my+mh-y)*SCALE),fill=255)
                    tile.putalpha(ImageChops.multiply(tile.getchannel("A"),mask))
        elif obj.kind=="StatusBar":
            tile=Image.new("RGBA",(W,H),(0,0,0,0));td=ImageDraw.Draw(tile)
            amount=(obj.value or 0)/max(1,obj.maximum or 1); color=rgba(obj.SetStatusBarColorArgs,(30,145,40,255))
            fill=max(0,min(W,round(W*amount)))
            start,end=(W-fill,W-1) if obj.reverseFill else (0,fill-1)
            art=obj.statusTexture.atlas if obj.statusTexture is not None else None
            texture=obj.statusTexture.texture if obj.statusTexture is not None else None
            flat_fill=texture is not None and "white8x8" in str(texture).lower()
            if art=="raidframe-shield-fill": color=(150,211,245,217)
            elif art=="raidframe-absorb-fill": color=(116,70,145,217)
            if fill:
                for py in range(H):
                    k=1 if flat_fill else .68+.32*math.sin(math.pi*py/max(1,H))
                    c=tuple(round(v*k) for v in color[:3])+(color[3],)
                    td.line((start,py,end,py),fill=c)
                if art:
                    # Native atlas artwork is not available to the offline renderer;
                    # approximate its pattern only, retaining actual fill geometry.
                    pattern=Image.new("RGBA",(fill,H),(0,0,0,0));pd=ImageDraw.Draw(pattern)
                    for sx in range(-H,fill+H,7):pd.line((sx,0,sx+H,H),fill=(235,245,255,75),width=1)
                    tile.alpha_composite(pattern,(start,0))
        elif obj.kind=="FontString":
            txt=content(obj)
            if not txt:continue
            tile=Image.new("RGBA",(W,H),(0,0,0,0));td=ImageDraw.Draw(tile);f=font(obj)
            align=(obj.SetJustifyHArgs[1] if obj.SetJustifyHArgs else "CENTER").lower()
            lines=[txt]
            if obj.SetWordWrapArgs and obj.SetWordWrapArgs[1]:
                lines=[];line=""
                for word in txt.split():
                    test=(line+" "+word).strip()
                    if td.textlength(test,font=f)>W and line:lines.append(line);line=word
                    else:line=test
                if line:lines.append(line)
            color=rgba(obj.SetTextColorArgs,(239,230,207,255))
            for n,line in enumerate(lines):
                tw=td.textlength(line,font=f);tx=0 if align=="left" else W-tw if align=="right" else (W-tw)/2
                # Use one baseline for digits, hyphens and punctuation. Ink-top
                # anchoring falsely lifted unavailable '--' against the trim.
                td.text((tx,n*round(12*SCALE)-f.getbbox("Hg")[1]),line,font=f,anchor="la",fill=color,stroke_width=1,stroke_fill=(0,0,0,220))
        elif obj.kind == "Button" and obj.renderText and not obj.fontString:
            tile=Image.new("RGBA",(W,H),(32,30,24,255));td=ImageDraw.Draw(tile)
            td.rectangle((0,0,W-1,H-1),outline=(142,120,72,255),width=2)
            td.text((W/2,H/2),content(obj),font=font(obj),anchor="mm",fill=(230,220,185,255))
        elif obj.SetBackdropArgs is not None:
            config=obj.SetBackdropArgs[1]
            bg=rgba(obj.SetBackdropColorArgs,(22,20,17,245)) if config.bgFile else (0,0,0,0)
            tile=Image.new("RGBA",(W,H),bg)
            ImageDraw.Draw(tile).rectangle((0,0,W-1,H-1),outline=rgba(obj.SetBackdropBorderColorArgs,(135,117,80,255)),width=max(1,round(SCALE)))
        if tile is not None:
            a=alpha(obj)
            if a<1:tile.putalpha(tile.getchannel("A").point(lambda p:round(p*a)))
            ancestor=parent(obj)
            while ancestor is not None:
                if ancestor.SetClipsChildrenArgs and ancestor.SetClipsChildrenArgs[1]:
                    cx,cy,cw,ch=rect(ancestor)
                    clip=Image.new("L",tile.size,0)
                    bounds=(round((cx-x)*SCALE),round((cy-y)*SCALE),
                        round((cx+cw-x)*SCALE)-1,round((cy+ch-y)*SCALE)-1)
                    if bounds[2]>=bounds[0] and bounds[3]>=bounds[1]:
                        ImageDraw.Draw(clip).rectangle(bounds,fill=255)
                    tile.putalpha(ImageChops.multiply(tile.getchannel("A"),clip))
                ancestor=parent(ancestor)
            blend = obj.blendMode or (obj.SetBlendModeArgs[1] if obj.SetBlendModeArgs else None)
            if blend == "ADD":
                # Native action glows use black as zero contribution, not an
                # opaque black background. Preserve the recorded blend mode.
                region=canvas.crop((X,Y,X+W,Y+H)).convert("RGB")
                contribution=ImageChops.multiply(tile.convert("RGB"),tile.getchannel("A").convert("RGB"))
                canvas.paste(ImageChops.add(region,contribution).convert("RGBA"),(X,Y))
            else:
                canvas.alpha_composite(tile,(X,Y))
    draw=ImageDraw.Draw(canvas)
    caption="OFFLINE LUA LAYOUT · native trim + spell art · preview class icons; live frames use portraits"
    if "--hover" in sys.argv: caption="OFFLINE HOVER STRIPS · invented test spell amounts · actual 2px addon geometry; artwork approximated"
    if "--history" in sys.argv:
        caption="OFFLINE HEALTH HISTORY · shipped /wpf test samples · 12px history"
        if "--hover" in sys.argv: caption += " + 2px hover overlay"
    if "--cleanses" in sys.argv:
        caption="OFFLINE RADIAL CLEANSES · actual Lua geometry and TGA art · sample alerts; not game casting"
    if "--parity" in sys.argv:
        caption="OFFLINE /wpf test · shipped member samples and layout; spell estimates and art approximated"
    draw.text((round(22*SCALE),round(18*SCALE)),caption,font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",round(12*SCALE)),fill=(210,210,205))
    draw.text((round(22*SCALE),canvas.height-round(25*SCALE)),"Actual addon geometry; fonts, patterns, glows and cooldowns approximated. Not an in-game screenshot.",font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",round(10*SCALE)),fill=(165,165,160))
    suffix = "-radial" if "--cleanses" in sys.argv else ""
    if "--quadrants" in sys.argv: suffix += "-quadrants"
    if "--shift" in sys.argv: suffix += "-shift"
    if "--menu-open" in sys.argv: suffix += "-menu"
    if "--prompt" in sys.argv: suffix += "-prompt"
    if "--predictions" in sys.argv: suffix += "-predictions"
    if "--hover" in sys.argv: suffix += "-hover"
    if "--history" in sys.argv: suffix += "-history"
    if "--parity" in sys.argv: suffix += "-parity"
    filename = "layout-preview" + suffix + ".png"
    destination=ROOT/".work"/filename;canvas.convert("RGB").save(destination)
    print(destination)
    print("Unmapped textures:",", ".join(sorted(missing)) or "none")
    if approximations: print("Symbolic native badge approximations:",", ".join(sorted(approximations)))


if __name__=="__main__":main()
