# app/db/seed/uom_seed.py

from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.models.item import Item
from app.db.models.item_alias import ItemAlias


def seed_aliases(db: Session, created_by: str = "system") -> None:
    aliases = [
        {
            "alias_name": "APPLE FUJI IMP USA (KG)",
            "alias_code": "590000001",
            "item_name": "APPLE FUJI",
        },
        {"alias_name": "Avocado", "alias_code": "590003579", "item_name": "AVACADO"},
        {
            "alias_name": "ONION ECONOMY (KG)",
            "alias_code": "590001600",
            "item_name": "ONION",
        },
        {
            "alias_name": "APPLE FUJI (KG)",
            "alias_code": "1982",
            "item_name": "APPLE FUJI ",
        },
        {
            "alias_name": "APPLE FUJI IMP USA (KG)",
            "alias_code": "590000001",
            "item_name": "APPLE FUJI ",
        },
        {
            "alias_name": "APPLE GRANNY SMITH USA (KG)",
            "alias_code": "590000003",
            "item_name": "APPLE GRANNY SMITH ",
        },
        {
            "alias_name": "APPLE JAMMU KASHMIR VALUE",
            "alias_code": "590001702",
            "item_name": "APPLE JAMMU KASHMIR VALUE",
        },
        {
            "alias_name": "APPLE PINK LADY NZ (KG )",
            "alias_code": "590000842",
            "item_name": "APPLE PINK LADY",
        },
        {
            "alias_name": "APPLE RED DELICIOUS USA (KG)",
            "alias_code": "590000002",
            "item_name": "APPLE RED DELICIOUS ",
        },
        {
            "alias_name": "APPLE ROYAL GALA POLAND (KG)",
            "alias_code": "590000005",
            "item_name": "APPLE ROYAL GALA ",
        },
        {
            "alias_name": "APPLE SIMLA (KG)",
            "alias_code": "590000009",
            "item_name": "APPLE SHIMLA ",
        },
        {"alias_name": "AVACADO", "alias_code": "590003579", "item_name": "AVACADO"},
        {
            "alias_name": "BABY CORN PEELED 200 GM",
            "alias_code": "590004229",
            "item_name": "BABY CORN PEELED 200 GM",
        },
        {
            "alias_name": "BANANA KARPURAVALLI KG",
            "alias_code": "590000615",
            "item_name": "BANANA KARPURAVALLI ",
        },
        {
            "alias_name": "BANANA RAW (KG)",
            "alias_code": "590000502",
            "item_name": "BANANA RAW ",
        },
        {
            "alias_name": "BANANA ROBUSTA",
            "alias_code": "590000454",
            "item_name": "BANANA ROBUSTA",
        },
        {
            "alias_name": "BEET ROOT (KG)",
            "alias_code": "590000129",
            "item_name": "BEET ROOT ",
        },
        {
            "alias_name": "BEST FARM DRAGON FRUIT (WHITE FLESH)",
            "alias_code": "590003307",
            "item_name": "DRAGON FRUIT",
        },
        {
            "alias_name": "BITTER GOURD (KG)",
            "alias_code": "590000173",
            "item_name": "BITTER GOURD ",
        },
        {
            "alias_name": "BLUE BERRY IMPORTED",
            "alias_code": "590000849",
            "item_name": "BLUE BERRY",
        },
        {
            "alias_name": "BOTTLE GOURD (KG)",
            "alias_code": "590000174",
            "item_name": "BOTTLE GOURD ",
        },
        {
            "alias_name": "BOTTLE GOURD EA",
            "alias_code": "590001217",
            "item_name": "BOTTLE GOURD ",
        },
        {
            "alias_name": "BRINJAL BLACK BIG (KG)",
            "alias_code": "590000161",
            "item_name": "BRINJAL BLACK BIG ",
        },
        {
            "alias_name": "BRINJAL LONG PURPLE (KG)",
            "alias_code": "590000163",
            "item_name": "BRINJAL LONG PURPLE ",
        },
        {
            "alias_name": "BUTTON MUSHROOM 200GM TP",
            "alias_code": "590000245",
            "item_name": "BUTTON MUSHROOM 200GM TP",
        },
        {
            "alias_name": "CABBAGE REGULAR (KG)",
            "alias_code": "590000142",
            "item_name": "CABBAGE REGULAR ",
        },
        {
            "alias_name": "CAPSICUM GREEN",
            "alias_code": "590000143",
            "item_name": "CAPSICUM GREEN",
        },
        {
            "alias_name": "CAPSICUM RED (KG)",
            "alias_code": "590000144",
            "item_name": "CAPSICUM RED ",
        },
        {
            "alias_name": "CAPSICUM YELLOW (KG)",
            "alias_code": "590000145",
            "item_name": "CAPSICUM YELLOW ",
        },
        {
            "alias_name": "CARROT DELHI (KG)",
            "alias_code": "590000264",
            "item_name": "CARROT DELHI",
        },
        {
            "alias_name": "CARROT REGULAR (KG)",
            "alias_code": "590000186",
            "item_name": "CARROT REGULAR ",
        },
        {
            "alias_name": "CHILLI GREEN DARK (KG)",
            "alias_code": "590000187",
            "item_name": "CHILLI GREEN ",
        },
        {
            "alias_name": "COCONUT TENDER",
            "alias_code": "590000097",
            "item_name": "COCONUT TENDER",
        },
        {
            "alias_name": "BIG COCONUT EA",
            "alias_code": "590000086",
            "item_name": "COCONUT",
        },
        {
            "alias_name": "COCONUT(EA)",
            "alias_code": "590002624",
            "item_name": "COCONUT",
        },
        {
            "alias_name": "COCCINIEA (KG)",
            "alias_code": "590000175",
            "item_name": "COCCINIEA",
        },
        {
            "alias_name": "CORRIANDER KGS",
            "alias_code": "590000554",
            "item_name": "CORRIANDER S",
        },
        {
            "alias_name": "CUCUMBER KEERA (KG)",
            "alias_code": "590000259",
            "item_name": "CUCUMBER KEERA ",
        },
        {
            "alias_name": "FRENCH BEANS (KG)",
            "alias_code": "590000157",
            "item_name": "FRENCH BEANS ",
        },
        {
            "alias_name": "GARLIC INDIAN (KG)",
            "alias_code": "590000131",
            "item_name": "GARLIC INDIAN ",
        },
        {
            "alias_name": "GINGER (KG)",
            "alias_code": "590000132",
            "item_name": "GINGER ",
        },
        {
            "alias_name": "GOOSEBERRY AMLA BIG KG",
            "alias_code": "590000126",
            "item_name": "GOOSEBERRY AMLA BIG ",
        },
        {
            "alias_name": "GRAPES IMP RED GLOBE CHINA (KG)",
            "alias_code": "590000034",
            "item_name": "GRAPES IMP RED GLOBE CHINA ",
        },
        {
            "alias_name": "GRAPES SONAKA PACK",
            "alias_code": "590004002",
            "item_name": "GRAPES SONAKA PACK",
        },
        {
            "alias_name": "GUAVA WHITE (KG)",
            "alias_code": "590000067",
            "item_name": "GUAVA WHITE",
        },
        {
            "alias_name": "BABY KIWI IMPORTED 6 PIECE PACK",
            "alias_code": "590008484",
            "item_name": "KIWI",
        },
        {
            "alias_name": "KIWI IMPORTED ECONOMY 3PC PACK",
            "alias_code": "590009674",
            "item_name": "KIWI",
        },
        {"alias_name": "LEMON (EA)", "alias_code": "590000188", "item_name": "LEMON "},
        {"alias_name": "LITCHI KG", "alias_code": "590000865", "item_name": "LITCHI"},
        {
            "alias_name": "MANGO ALPHANSO",
            "alias_code": "590000261",
            "item_name": "MANGO ALPHANSO",
        },
        {
            "alias_name": "MANGO BANGANAPALLI",
            "alias_code": "590000651",
            "item_name": "MANGO BANGANAPALLI",
        },
        {
            "alias_name": "MANGO DUSSHERI",
            "alias_code": "590000660",
            "item_name": "MANGO DUSSHERI",
        },
        {
            "alias_name": "MANGO GULABKHAS (KG)",
            "alias_code": "590001551",
            "item_name": "MANGO GULABKHAS ",
        },
        {
            "alias_name": "MANGO HIMSAGAR (KG)",
            "alias_code": "590001552",
            "item_name": "MANGO HIMSAGAR",
        },
        {
            "alias_name": "MANGO KESAR",
            "alias_code": "590000724",
            "item_name": "MANGO KESAR",
        },
        {
            "alias_name": "MANGO LANGDA KG",
            "alias_code": "590000610",
            "item_name": "MANGO LANGDA ",
        },
        {
            "alias_name": "MANGO RASPURI KG",
            "alias_code": "590000604",
            "item_name": "MANGO RASPURI ",
        },
        {
            "alias_name": "MANGO TOTAPURI",
            "alias_code": "590000047",
            "item_name": "MANGO TOTAPURI",
        },
        {
            "alias_name": "MINT LEAVES BUNCH",
            "alias_code": "590000532",
            "item_name": "MINT LEAVES BUNCH",
        },
        {
            "alias_name": "MOSAMBI SMALL",
            "alias_code": "590001673",
            "item_name": "MOSAMBI SMALL",
        },
        {
            "alias_name": "MUSK MELON (KG)",
            "alias_code": "590000051",
            "item_name": "MUSK MELON ",
        },
        {"alias_name": "OKRA", "alias_code": "590000189", "item_name": "OKRA"},
        {"alias_name": "ONION", "alias_code": "590000087", "item_name": "ONION"},
        {
            "alias_name": "ONION 2 KG PACK (KG)",
            "alias_code": "590002741",
            "item_name": "ONION",
        },
        {
            "alias_name": "ONION ECONOMY (KG)",
            "alias_code": "590001600",
            "item_name": "ONION",
        },
        {
            "alias_name": "ORANGE IMPORTED EGYPT (KG)",
            "alias_code": "590000025",
            "item_name": "ORANGE IMPORTED EGYPT ",
        },
        {
            "alias_name": "ORANGE SMALL (KG)",
            "alias_code": "590001809",
            "item_name": "ORANGE SMALL ",
        },
        {
            "alias_name": "PAPAYA DISCO",
            "alias_code": "590000068",
            "item_name": "PAPAYA DISCO",
        },
        {
            "alias_name": "PEARS BABUGOSHA (KG)",
            "alias_code": "590001297",
            "item_name": "PEARS BABUGOSHA ",
        },
        {
            "alias_name": "PEARS IMP PACKHAM RSA (KG)",
            "alias_code": "590001296",
            "item_name": "PEARS IMP PACKHAM RSA ",
        },
        {
            "alias_name": "PINEAPPLE",
            "alias_code": "590001250",
            "item_name": "PINEAPPLE",
        },
        {
            "alias_name": "PLUM IMPORTED CHINA ( KG)",
            "alias_code": "590000029",
            "item_name": "PLUM IMPORTED CHINA ",
        },
        {
            "alias_name": "POINTED GOURD",
            "alias_code": "590000509",
            "item_name": "POINTED GOURD",
        },
        {
            "alias_name": "POMEGRANATE KESAR (KG)",
            "alias_code": "590000082",
            "item_name": "POMEGRANATE KESAR ",
        },
        {
            "alias_name": "POMEGRANATE KESAR SMALL 1 KG",
            "alias_code": "590004194",
            "item_name": "POMEGRANATE KESAR ",
        },
        {"alias_name": "POTATO", "alias_code": "590000090", "item_name": "POTATO"},
        {
            "alias_name": "POTATO 2 KG PACK",
            "alias_code": "590003309",
            "item_name": "POTATO",
        },
        {
            "alias_name": "POTATO BABY (KG)",
            "alias_code": "590000094",
            "item_name": "POTATO",
        },
        {
            "alias_name": "POTATO FRESH(KG)",
            "alias_code": "590001787",
            "item_name": "POTATO",
        },
        {
            "alias_name": "POTATO RED KG",
            "alias_code": "590001486",
            "item_name": "POTATO",
        },
        {
            "alias_name": "PUMPKIN DISCO (KG)",
            "alias_code": "590000190",
            "item_name": "PUMPKIN DISCO ",
        },
        {
            "alias_name": "RAW MANGO (KG)",
            "alias_code": "590000191",
            "item_name": "RAW MANGO ",
        },
        {
            "alias_name": "SPONGE GOURD (KG)",
            "alias_code": "590000697",
            "item_name": "SPONGE GOURD ",
        },
        {
            "alias_name": "SUGAR BABY MELON (KG)",
            "alias_code": "590000054",
            "item_name": "SUGAR BABY MELON",
        },
        {
            "alias_name": "SUN MELON KG",
            "alias_code": "590000578",
            "item_name": "SUN MELON ",
        },
        {
            "alias_name": "SWEET CORN SHELLED 200 GMS TP",
            "alias_code": "590001511",
            "item_name": "SWEET CORN SHELLED 200 GMS ",
        },
        {
            "alias_name": "SWEET POTATO (KG)",
            "alias_code": "590000138",
            "item_name": "SWEET POTATO ",
        },
        {
            "alias_name": "SWEET TAMARIND",
            "alias_code": "590001259",
            "item_name": "SWEET TAMARIND",
        },
        {
            "alias_name": "TENDER JACKFRUIT",
            "alias_code": "590000263",
            "item_name": "TENDER JACKFRUIT",
        },
        {"alias_name": "TOMATO", "alias_code": "590000092", "item_name": "TOMATO"},
        {
            "alias_name": "WATER MELON NAMDHARIKG",
            "alias_code": "590000758",
            "item_name": "WATER MELON NAMDHARI",
        },
        {
            "alias_name": "WATERMELON 5 KG",
            "alias_code": "590000052",
            "item_name": "WATERMELON",
        },
        {
            "alias_name": "WATERMELON KIRAN",
            "alias_code": "590000692",
            "item_name": "WATERMELON KIRAN",
        },
        {
            "alias_name": "WATERMELON SARASWATI (KG)",
            "alias_code": "590009768",
            "item_name": "WATERMELON SARASWATI ",
        },
        {
            "alias_name": "WOOD APPLE",
            "alias_code": "590000262",
            "item_name": "WOOD APPLE",
        },
    ]
    for a in aliases:
        item = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == a["item_name"].strip().lower())
            .first()
        )

        if (
            item
            and not db.query(ItemAlias)
            .filter(
                func.lower(func.trim(ItemAlias.alias_name))
                == a["alias_name"].strip().lower(),
                ItemAlias.master_item_id == item.id,
            )
            .first()
        ):
            db.add(
                ItemAlias(
                    master_item_id=item.id,
                    alias_name=a["alias_name"].strip(),
                    alias_code=a["alias_code"].strip(),
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
