#!/usr/bin/env python3
"""
v0.29 老板 OOB 同意按 C 方案: 拆 '李白与杜甫' → 2 个独立 entities
(李白 + 杜甫) + 加 subcategory = I2 (中国文学人物)

Usage: python3 Scripts/split-libai-dufu.py <library-root>
"""
import json
import sys
import os
from pathlib import Path
from datetime import datetime, timezone

if len(sys.argv) < 2:
    print("Usage: split-libai-dufu.py <library-root>")
    sys.exit(1)

library_root = Path(sys.argv[1])
entities_dir = library_root / "reference-library" / "entities"
entities_json_path = entities_dir / "entities.json"

# Load current index
with open(entities_json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# 1. Remove the old merged entity
old_entry = None
new_data = []
for e in data:
    if e["title"] == "李白与杜甫":
        old_entry = e
    else:
        new_data.append(e)

if old_entry is None:
    print("ERROR: 旧 '李白与杜甫' entity not found. Aborting.")
    sys.exit(1)

old_uuid = old_entry["id"]
old_md_path = entities_dir / "i" / f"{old_uuid}.md"
if old_md_path.exists():
    os.remove(old_md_path)
    print(f"Deleted old .md: {old_md_path}")
else:
    print(f"Old .md not found at {old_md_path} (= already deleted or never existed)")

# 2. Add 2 new entities (李白 + 杜甫) with subcategory = I2
now_iso = datetime.now(timezone.utc).isoformat()

li_bai = {
    "id": "11111111-AAAA-1111-AAAA-111111111111",
    "title": "李白",
    "summary": "唐代浪漫主义诗人, 被誉为 '诗仙', 字太白。",
    "layer": "layerEntities",
    "category": "I",
    "subcategory": "I2",
    "entityType": 1,  # v0.30: 1 = character
    "characterRefIds": [],
    "worldRefIds": [],
    "bookRefIds": [],
    "createdAt": now_iso,
    "updatedAt": now_iso,
    "url": None,
    "source": None,
}

du_fu = {
    "id": "22222222-BBBB-2222-BBBB-222222222222",
    "title": "杜甫",
    "summary": "唐代现实主义诗人, 被誉为 '诗圣', 字子美。",
    "layer": "layerEntities",
    "category": "I",
    "subcategory": "I2",
    "entityType": 1,  # v0.30: 1 = character
    "characterRefIds": [],
    "worldRefIds": [],
    "bookRefIds": [],
    "createdAt": now_iso,
    "updatedAt": now_iso,
    "url": None,
    "source": None,
}

new_data.append(li_bai)
new_data.append(du_fu)

# 3. Write .md bodies
i_dir = entities_dir / "i"
i_dir.mkdir(parents=True, exist_ok=True)

li_bai_body = """# 李白

李白 (701-762), 字太白, 号青莲居士, 是中国唐代最伟大的浪漫主义诗人之一, 被誉为 "诗仙"。

## 生平

李白生于碎叶城 (今吉尔吉斯斯坦境内), 5 岁随父迁居四川江油。早年遍游名山大川, 后因才名被召入长安供奉翰林, 但因遭谗言而离开。后因永王李璘案被流放夜郎, 遇赦后卒于当涂。

## 诗风

- 风格豪放飘逸, 想象瑰丽雄奇
- 语言清新自然, 音律和谐多变
- 多用夸张比喻与神话传说

## 代表作

- 《静夜思》: "床前明月光, 疑是地上霜"
- 《将进酒》: "君不见黄河之水天上来"
- 《蜀道难》: "噫吁嚱, 危乎高哉"
- 《早发白帝城》: "朝辞白帝彩云间"
- 《望庐山瀑布》: "飞流直下三千尺"

## 历史地位

李白的诗歌对中国后世影响深远, 是中华文化瑰宝的重要组成部分。
"""

du_fu_body = """# 杜甫

杜甫 (712-770), 字子美, 自号少陵野老, 是中国唐代最伟大的现实主义诗人之一, 被誉为 "诗圣", 与李白并称 "李杜"。

## 生平

杜甫生于河南巩县, 出身于 "杜少陵" 家族。少年时期家境优渥, 中年后经历安史之乱, 颠沛流离。后入蜀定居成都, 在浣花溪畔建草堂。最后病逝于湘江舟中。

## 诗风

- 风格沉郁顿挫, 反映社会现实
- 语言精炼有力, 被称为 "诗史"
- 关注民生疾苦与国家兴亡

## 代表作

- 《春望》: "国破山河在, 城春草木深"
- 《登高》: "无边落木萧萧下, 不尽长江滚滚来"
- 《茅屋为秋风所破歌》: "安得广厦千万间"
- 《春夜喜雨》: "好雨知时节, 当春乃发生"
- 《兵车行》: "车辚辚, 马萧萧"

## 历史地位

杜甫的诗歌记录了唐代由盛转衰的历史, 被誉为 "诗史", 对后世现实主义文学影响深远。
"""

li_bai_md_path = i_dir / f"{li_bai['id']}.md"
du_fu_md_path = i_dir / f"{du_fu['id']}.md"
with open(li_bai_md_path, "w", encoding="utf-8") as f:
    f.write(li_bai_body)
print(f"Wrote 李白 .md: {li_bai_md_path}")

with open(du_fu_md_path, "w", encoding="utf-8") as f:
    f.write(du_fu_body)
print(f"Wrote 杜甫 .md: {du_fu_md_path}")

# 4. Save updated entities.json
with open(entities_json_path, "w", encoding="utf-8") as f:
    json.dump(new_data, f, indent=2, ensure_ascii=False, sort_keys=True)
print(f"Updated entities.json: {len(new_data)} entries")

# Summary
print()
print("=" * 60)
print("v0.29 split 李白与杜甫 → 李白 + 杜甫 (both subcategory=I2)")
print("=" * 60)
print(f"Removed: 1 entity (李白与杜甫, id={old_uuid[:8]}...)")
print(f"Added:   2 entities (李白, 杜甫) both category=I, subcategory=I2")
print(f"Total:   {len(new_data)} entities")