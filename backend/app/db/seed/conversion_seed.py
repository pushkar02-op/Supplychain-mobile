# app/db/seed/conversion_seed.py

import logging
import unicodedata
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.item import Item
from datetime import datetime

logger = logging.getLogger(__name__)


def seed_conversions(db: Session, created_by: str = "system") -> None:
    conversions = [
        {
            "item_name": "APPLE AMBRI ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE FUJI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE GRANNY SMITH ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE JAMMU KASHMIR VALUE",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE PINK LADY",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE RED DELICIOUS ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE ROYAL GALA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "APPLE SHIMLA",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.181818182,
        },
        {
            "item_name": "AVACADO",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 2.5,
        },
        {
            "item_name": "BABY CORN PEELED 200 GM",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.149253731,
        },
        {
            "item_name": "BANANA KARPURAVALLI ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.149253731,
        },
        {
            "item_name": "BANANA RAW ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.149253731,
        },
        {
            "item_name": "BANANA ROBUSTA",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BEET ROOT ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "DRAGON FRUIT (WHITE FLESH)",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 1.25,
        },
        {
            "item_name": "BITTER GOURD ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BLUE BERRY",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BOTTLE GOURD ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BRINJAL BLACK BIG ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BRINJAL LONG GREEN",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 2,
        },
        {
            "item_name": "BRINJAL LONG PURPLE ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BRINJAL NAGPURE",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "BUTTON MUSHROOM 200GM TP",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CABBAGE REGULAR ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CAPSICUM GREEN",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CAPSICUM RED ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CAPSICUM YELLOW ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CARROT DELHI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.066666667,
        },
        {
            "item_name": "CARROT REGULAR ",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 2,
        },
        {
            "item_name": "CHILLI GREEN ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "COCCINIEA",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.05,
        },
        {
            "item_name": "COCONUT",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 6.5,
        },
        {
            "item_name": "COCONUT TENDER",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 12,
        },
        {
            "item_name": "CORRIANDER S",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "CUCUMBER KEERA ",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 5,
        },
        {
            "item_name": "FRENCH BEANS ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "GARLIC INDIAN ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.033333333,
        },
        {
            "item_name": "GINGER ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "GOOSEBERRY AMLA BIG ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "GRAPES IMP RED GLOBE CHINA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.01,
        },
        {
            "item_name": "GRAPES SONAKA PACK",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 5,
        },
        {
            "item_name": "GUAVA WHITE",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "KIWI",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 1,
        },
        {
            "item_name": "LEMON",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.7,
        },
        {
            "item_name": "LITCHI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "MANGO ALPHANSO",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO BANGANAPALLI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO DUSSHERI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO GULABKHAS ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO HIMSAGAR",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO JARDALU",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO KESAR",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO LANGDA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO NEELAM",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO RASPURI ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MANGO SINDURI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1.25,
        },
        {
            "item_name": "MANGO TOTAPURI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.25,
        },
        {
            "item_name": "MINT LEAVES BUNCH",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 1,
        },
        {
            "item_name": "MOSAMBI SMALL",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "MUSK MELON ",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 15,
        },
        {
            "item_name": "OKRA",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.033333333,
        },
        {
            "item_name": "ONION",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "ORANGE IMPORTED EGYPT ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "ORANGE SMALL ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "PAPAYA DISCO",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.033333333,
        },
        {
            "item_name": "PEARS BABUGOSHA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.5,
        },
        {
            "item_name": "PEARS IMP PACKHAM RSA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "P GARLIC",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "PINEAPPLE",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 12,
        },
        {
            "item_name": "PLUM IMPORTED CHINA ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.125,
        },
        {
            "item_name": "POINTED GOURD",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.05,
        },
        {
            "item_name": "POMEGRANATE KESAR ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "POTATO",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "PUMPKIN DISCO ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.5,
        },
        {
            "item_name": "RAW MANGO ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.222222222,
        },
        {
            "item_name": "SPONGE GOURD ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.05,
        },
        {
            "item_name": "SUGAR BABY MELON",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1,
        },
        {
            "item_name": "SUN MELON ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1,
        },
        {
            "item_name": "SWEET CORN SHELLED 200 GMS",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 2,
        },
        {
            "item_name": "SWEET POTATO ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "SWEET TAMARIND",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 2,
        },
        {
            "item_name": "TENDER JACKFRUIT",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.666666667,
        },
        {
            "item_name": "TOMATO",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.1,
        },
        {
            "item_name": "WATERMELON",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "WATERMELON KIRAN",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "WATER MELON NAMDHARI",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "WATERMELON SARASWATI ",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 0.2,
        },
        {
            "item_name": "WOOD APPLE",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1,
        },
    ]

    for c in conversions:
        item = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == c["item_name"].strip().lower())
            .first()
        )
        if not item:
            logger.debug(f"Item not found for: {repr(c['item_name'])}")
            continue

        exists = (
            db.query(ItemConversionMap)
            .filter_by(
                item_id=item.id,
            )
            .first()
        )

        if not exists:
            db.add(
                ItemConversionMap(
                    item_id=item.id,
                    source_unit=c["source_unit"].strip(),
                    target_unit=c["target_unit"].strip(),
                    conversion_factor=c["factor"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
