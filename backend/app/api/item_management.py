# backend/app/api/item_management.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.db.session import get_db
from app.db.models import Item, ItemAlias, UOM, ItemConversionMap
from app.db.schemas.item_management import (
    ItemManagementCreateUpdate,
    ItemManagementRead,
    UOMRead,
    AliasMapInput,
)
from app.db.schemas.item_alias import ItemAliasRead
from app.core.auth import get_current_user
from app.db.models.user import User

router = APIRouter(prefix="/item-management", tags=["Item Management"])


@router.get("/", response_model=List[ItemManagementRead])
def get_items(db: Session = Depends(get_db)):
    items = db.query(Item).all()
    result = []
    for item in items:
        aliases = db.query(ItemAlias).filter(ItemAlias.master_item_id == item.id).all()
        conversions = (
            db.query(ItemConversionMap)
            .filter(ItemConversionMap.item_id == item.id)
            .all()
        )
        uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
        result.append(
            ItemManagementRead(
                id=item.id,
                name=item.name,
                default_uom_code=uom.code if uom else None,
                aliases=aliases,
                conversions=conversions,
            )
        )
    return result


@router.get("/uoms", response_model=List[UOMRead])
def get_uoms(db: Session = Depends(get_db)):
    return db.query(UOM).order_by(UOM.code).all()


@router.get("/unmapped-aliases", response_model=List[ItemAliasRead])
def get_unmapped_aliases(db: Session = Depends(get_db)):
    aliases = (
        db.query(ItemAlias)
        .filter(ItemAlias.master_item_id == None)
        .order_by(ItemAlias.alias_name)
        .all()
    )
    return aliases


@router.post("/", response_model=ItemManagementRead)
def create_or_update_item(
    payload: ItemManagementCreateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = None
    if payload.id:
        item = db.query(Item).filter(Item.id == payload.id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Item not found")
        item.name = payload.name
        item.default_uom_id = payload.default_uom_id
    else:
        item = Item(
            name=payload.name,
            default_uom_id=payload.default_uom_id,
            created_by=current_user.username,
        )
        db.add(item)
        db.flush()

    # Clear and re-add aliases
    db.query(ItemAlias).filter(
        ItemAlias.master_item_id == item.id,
        ~ItemAlias.id.in_([a.id for a in payload.aliases]),
    ).update({"master_item_id": None})
    for alias in payload.aliases:
        db_alias = (
            db.query(ItemAlias).filter(ItemAlias.alias_code == alias.alias_code).first()
        )
        if db_alias:
            db_alias.master_item_id = item.id
        else:
            db.add(
                ItemAlias(
                    master_item_id=item.id,
                    alias_code=alias.alias_code,
                    alias_name=alias.alias_name,
                    created_by=current_user.username,
                )
            )

    # Clear and re-add conversions
    db.query(ItemConversionMap).filter(ItemConversionMap.item_id == item.id).delete()
    for conv in payload.conversions:
        db.add(
            ItemConversionMap(
                item_id=item.id,
                source_unit=conv.source_unit,
                target_unit=conv.target_unit,
                conversion_factor=conv.conversion_factor,
                created_by=current_user.username,
            )
        )

    db.commit()
    db.refresh(item)

    # Return full details
    aliases = db.query(ItemAlias).filter(ItemAlias.master_item_id == item.id).all()
    conversions = (
        db.query(ItemConversionMap).filter(ItemConversionMap.item_id == item.id).all()
    )
    uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
    return ItemManagementRead(
        id=item.id,
        name=item.name,
        default_uom_code=uom.code if uom else None,
        aliases=aliases,
        conversions=conversions,
    )


@router.post("/map-alias")
def map_alias_to_item(payload: AliasMapInput, db: Session = Depends(get_db)):
    alias = db.query(ItemAlias).filter(ItemAlias.id == payload.alias_id).first()
    if not alias:
        raise HTTPException(status_code=404, detail="Alias not found")
    alias.master_item_id = payload.item_id
    db.commit()
    return {"message": "Alias mapped successfully"}
