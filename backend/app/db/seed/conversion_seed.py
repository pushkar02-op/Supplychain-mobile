# app/db/seed/conversion_seed.py

from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.item import Item
from datetime import datetime


def seed_conversions(db: Session, created_by: str = "system") -> None:
    conversions = [
        # Apples (150‑200 g average → ~5.5 EA/kg → KG→EA)
        {
            "item_name": "Apple Ambri",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Fuji",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Granny Smith",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Jammu Kashmir Value",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Pink Lady",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Red Delicious",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Royal Gala",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        {
            "item_name": "Apple Shimla Value Pack",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.5,
        },
        # Avocado (250 g each)
        {
            "item_name": "Avacado",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.25,
        },
        # Bananas (~150 g each → ~6.7 EA/kg)
        {
            "item_name": "Banana Karpuravalli",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 6.7,
        },
        {
            "item_name": "Banana Raw",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 6.7,
        },
        {
            "item_name": "Banana Robusta",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 6.7,
        },
        # Other KG→EA produce (~200–300g → ~4.5 EA/kg)
        {
            "item_name": "Beet Root",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Bitter Gourd",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Bottle Gourd",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Brinjal Black Big",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Brinjal Long Green",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Brinjal Long Purple",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Cabbage Regular",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Capsicum Green",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Capsicum Red",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Capsicum Yellow",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Carrot Delhi",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Carrot Regular",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Chilli Green",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 15,
        },  # Smaller, ~65 g → ~15 EA/kg
        {
            "item_name": "Coccineia",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        # Mushrooms: average 200 g for 200gm pack → EA→KG
        {
            "item_name": "Button Mushroom 200gm TP",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.2,
        },
        {
            "item_name": "BABY CORN PEELED 200 GM",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.2,
        },
        {
            "item_name": "Corriander S",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Cucumber Keera",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        # Dragon Fruit ~500 g each
        {
            "item_name": "Dragon Fruit",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.5,
        },
        {
            "item_name": "French Beans",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 10,
        },
        {
            "item_name": "Garlic Indian",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 30,
        },
        {"item_name": "Ginger", "source_unit": "KG", "target_unit": "EA", "factor": 10},
        {
            "item_name": "Gooseberry Amla Big",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 10,
        },
        {
            "item_name": "Grapes Imp Red Globe China",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 100,
        },  # units bunches
        {
            "item_name": "Grapes Sonaka Pack",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.5,
        },
        {
            "item_name": "Guava White",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        # Kiwis ~75–100 g → EA→KG
        {"item_name": "Kiwi", "source_unit": "EA", "target_unit": "KG", "factor": 0.1},
        # Lemons ~70 g each
        {
            "item_name": "Lemon",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.07,
        },
        {
            "item_name": "Litchi",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        # Mangoes vary; ~250 g each → ~4 EA/kg
        {
            "item_name": "Mango Alphanso",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Banganapalli",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Dusshheri",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Gulabkhas",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Himsagar",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Kesar",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Langda",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Raspuri",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        {
            "item_name": "Mango Totapuri",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4,
        },
        # Mint Leaves bunch ~0.1 kg
        {
            "item_name": "Mint Leaves Bunch",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.1,
        },
        # Mosambi medium ~0.2 kg each
        {
            "item_name": "Mosambi Small",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        # Muskmelon ~1.5 kg each
        {
            "item_name": "Musk Melon",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 1.5,
        },
        {"item_name": "Okra", "source_unit": "KG", "target_unit": "EA", "factor": 30},
        {"item_name": "Onion", "source_unit": "KG", "target_unit": "EA", "factor": 10},
        # Oranges small ~0.2 kg
        {
            "item_name": "Orange Imported Egypt",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "Orange Small",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "P Garlic",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 30,
        },
        {
            "item_name": "Papaya Disco",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 2,
        },  # ~500 g
        {
            "item_name": "Pears Babugosha",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Pears Imp Packham RSA",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        # Pineapple ~1.2 kg
        {
            "item_name": "Pineapple",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 1.2,
        },
        {
            "item_name": "Plum Imported China",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 8,
        },
        {
            "item_name": "Pointed Gourd",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 20,
        },
        {
            "item_name": "Pomegranate Kesar",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {"item_name": "Potato", "source_unit": "KG", "target_unit": "EA", "factor": 10},
        {
            "item_name": "Pumpkin Disco",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 2,
        },
        {
            "item_name": "Raw Mango",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 4.5,
        },
        {
            "item_name": "Sponge Gourd",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 20,
        },
        {
            "item_name": "Sugar Baby Melon",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1,
        },
        {
            "item_name": "Sun Melon",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1,
        },
        # Sweet Corn shelled 200g pack
        {
            "item_name": "Sweet Corn Shelled 200 GMS",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.2,
        },
        {
            "item_name": "Sweet Potato",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        # Sweet Tamarind ~0.2 kg
        {
            "item_name": "Sweet Tamarind",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 0.2,
        },
        {
            "item_name": "Tender Jackfruit",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 1.5,
        },
        {"item_name": "Tomato", "source_unit": "KG", "target_unit": "EA", "factor": 10},
        # Watermelons ~5 kg each
        {
            "item_name": "Water Melon Namdhari",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "Watermelon",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "Watermelon Kiran",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "Watermelon Saraswati",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5,
        },
        {
            "item_name": "Wood Apple",
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

        if (
            item
            and not db.query(ItemConversionMap)
            .filter_by(
                item_id=item.id,
                source_unit=c["source_unit"].strip().lower(),
                target_unit=c["target_unit"].strip().lower(),
            )
            .first()
        ):
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
