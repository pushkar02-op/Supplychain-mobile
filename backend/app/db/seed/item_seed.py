# app/db/seed/item_seed.py

from sqlalchemy.orm import Session
from app.db.models.item import Item
from app.db.models.uom import UOM
from datetime import datetime


def seed_items(db: Session, created_by: str = "system") -> None:
    item_data = [
        {"name": "APPLE AMBRI ", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE FUJI", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE GRANNY SMITH ", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE JAMMU KASHMIR VALUE", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE PINK LADY", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE RED DELICIOUS ", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE ROYAL GALA ", "item_code": "", "default_uom": "KG"},
        {"name": "APPLE SHIMLA VALUE PACK", "item_code": "", "default_uom": "KG"},
        {"name": "AVACADO", "item_code": "", "default_uom": "EA"},
        {"name": "BANANA KARPURAVALLI ", "item_code": "", "default_uom": "KG"},
        {"name": "BANANA RAW ", "item_code": "", "default_uom": "KG"},
        {"name": "BANANA ROBUSTA", "item_code": "", "default_uom": "KG"},
        {"name": "BEET ROOT ", "item_code": "", "default_uom": "KG"},
        {
            "name": "BEST FARM DRAGON FRUIT (WHITE FLESH)",
            "item_code": "",
            "default_uom": "EA",
        },
        {"name": "BITTER GOURD ", "item_code": "", "default_uom": "KG"},
        {"name": "BOTTLE GOURD ", "item_code": "", "default_uom": "KG"},
        {"name": "BRINJAL BLACK BIG ", "item_code": "", "default_uom": "KG"},
        {"name": "BRINJAL LONG GREEN", "item_code": "", "default_uom": "KG"},
        {"name": "BRINJAL LONG PURPLE ", "item_code": "", "default_uom": "KG"},
        {"name": "BUTTON MUSHROOM 200GM TP", "item_code": "", "default_uom": "EA"},
        {"name": "CABBAGE REGULAR ", "item_code": "", "default_uom": "KG"},
        {"name": "CAPSICUM GREEN", "item_code": "", "default_uom": "KG"},
        {"name": "CAPSICUM RED ", "item_code": "", "default_uom": "KG"},
        {"name": "CAPSICUM YELLOW ", "item_code": "", "default_uom": "KG"},
        {"name": "CARROT REGULAR ", "item_code": "", "default_uom": "KG"},
        {"name": "CHILLI GREEN ", "item_code": "", "default_uom": "KG"},
        {"name": "COCCINIEA ", "item_code": "", "default_uom": "KG"},
        {"name": "COCONUT TENDER", "item_code": "", "default_uom": "EA"},
        {"name": "COCONUT", "item_code": "", "default_uom": "EA"},
        {"name": "CORRIANDER S", "item_code": "", "default_uom": "KG"},
        {"name": "CUCUMBER KEERA ", "item_code": "", "default_uom": "KG"},
        {"name": "FRENCH BEANS ", "item_code": "", "default_uom": "KG"},
        {"name": "GARLIC INDIAN ", "item_code": "", "default_uom": "KG"},
        {"name": "GINGER ", "item_code": "", "default_uom": "KG"},
        {"name": "GOOSEBERRY AMLA BIG ", "item_code": "", "default_uom": "KG"},
        {"name": "GRAPES IMP RED GLOBE CHINA ", "item_code": "", "default_uom": "KG"},
        {"name": "GRAPES SONAKA PACK", "item_code": "", "default_uom": "EA"},
        {"name": "KIWI", "item_code": "", "default_uom": "EA"},
        {"name": "LEMON ", "item_code": "", "default_uom": "EA"},
        {"name": "MANGO BANGANAPALLI", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO DUSSHERI", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO GULABKHAS ", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO KESAR", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO LANGDA ", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO RASPURI ", "item_code": "", "default_uom": "KG"},
        {"name": "MANGO TOTAPURI", "item_code": "", "default_uom": "KG"},
        {"name": "MINT LEAVES BUNCH", "item_code": "", "default_uom": "EA"},
        {"name": "MOSAMBI SMALL", "item_code": "", "default_uom": "KG"},
        {"name": "MUSK MELON ", "item_code": "", "default_uom": "KG"},
        {"name": "OKRA", "item_code": "", "default_uom": "KG"},
        {"name": "ONION", "item_code": "", "default_uom": "KG"},
        {"name": "ORANGE IMPORTED EGYPT ", "item_code": "", "default_uom": "KG"},
        {"name": "ORANGE SMALL ", "item_code": "", "default_uom": "KG"},
        {"name": "P GARLIC", "item_code": "", "default_uom": "KG"},
        {"name": "PAPAYA DISCO", "item_code": "", "default_uom": "KG"},
        {"name": "PEARS BABUGOSHA ", "item_code": "", "default_uom": "KG"},
        {"name": "PEARS IMP PACKHAM RSA ", "item_code": "", "default_uom": "KG"},
        {"name": "PINEAPPLE", "item_code": "", "default_uom": "EA"},
        {"name": "PLUM IMPORTED CHINA ", "item_code": "", "default_uom": "KG"},
        {"name": "POINTED GOURD", "item_code": "", "default_uom": "KG"},
        {"name": "POMEGRANATE KESAR ", "item_code": "", "default_uom": "KG"},
        {"name": "POTATO", "item_code": "", "default_uom": "KG"},
        {"name": "PUMPKIN DISCO ", "item_code": "", "default_uom": "KG"},
        {"name": "RAW MANGO ", "item_code": "", "default_uom": "KG"},
        {"name": "SPONGE GOURD ", "item_code": "", "default_uom": "KG"},
        {"name": "SUN MELON ", "item_code": "", "default_uom": "KG"},
        {"name": "SWEET POTATO ", "item_code": "", "default_uom": "KG"},
        {"name": "SWEET TAMARIND", "item_code": "", "default_uom": "EA"},
        {"name": "TENDER JACKFRUIT", "item_code": "", "default_uom": "KG"},
        {"name": "TOMATO", "item_code": "", "default_uom": "KG"},
        {"name": "WATER MELON NAMDHARI", "item_code": "", "default_uom": "KG"},
        {"name": "WATERMELON 5 ", "item_code": "", "default_uom": "KG"},
        {"name": "WATERMELON KIRAN", "item_code": "", "default_uom": "KG"},
        {"name": "WATERMELON SARASWATI ", "item_code": "", "default_uom": "KG"},
    ]

    for item in item_data:
        uom = db.query(UOM).filter_by(code=item["default_uom"]).first()
        if not uom:
            continue
        exists = db.query(Item).filter_by(name=item["name"]).first()
        if not exists:
            db.add(
                Item(
                    name=item["name"],
                    default_uom_id=uom.id,
                    item_code=item["item_code"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
