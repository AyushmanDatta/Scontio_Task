from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from web3 import Web3
from hashlib import sha256
import json

# =====================================================
# CONFIG (GANACHE)
# =====================================================

GANACHE_RPC = "http://127.0.0.1:8545"

CONTRACT_ADDRESS = "0xD9145CCE52D386f254917e481eB44e9943F39138"

SUPER_ADMIN = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
INSTITUTION_ADMIN = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"

# =====================================================
# WEB3 INIT
# =====================================================

w3 = Web3(Web3.HTTPProvider(GANACHE_RPC))
if not w3.is_connected():
    raise Exception("❌ Ganache not running")

with open("abi.json") as f:
    ABI = json.load(f)

contract = w3.eth.contract(
    address=w3.to_checksum_address(CONTRACT_ADDRESS),
    abi=ABI
)

# =====================================================
# FASTAPI INIT
# =====================================================

app = FastAPI(title="Sconto Identity API (Ganache)")

# =====================================================
# REQUEST MODELS
# =====================================================

class InstitutionCreate(BaseModel):
    institution_admin: str
    name: str

class InstitutionStatus(BaseModel):
    institution_id: int
    authorized: bool

class DepartmentCreate(BaseModel):
    name: str

class BatchCreate(BaseModel):
    department_id: int
    year: int

class StudentCreate(BaseModel):
    wallet: str
    department_id: int
    year: int
    name: str
    student_id: str
    photo_base64: str

# =====================================================
# TRANSACTION HELPER
# =====================================================

def send_tx(tx_func, sender):
    tx = tx_func.build_transaction({
        "from": sender,
        "nonce": w3.eth.get_transaction_count(sender),
        "gas": 3_000_000,
        "gasPrice": w3.to_wei("20", "gwei")
    })

    tx_hash = w3.eth.send_transaction(tx)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    return receipt.transactionHash.hex()

# =====================================================
# SUPER ADMIN APIs
# =====================================================

@app.post("/admin/institution")
def add_institution(data: InstitutionCreate):
    tx_hash = send_tx(
        contract.functions.addInstitution(
            w3.to_checksum_address(data.institution_admin),
            data.name
        ),
        SUPER_ADMIN
    )
    return {"status": "ok", "txHash": tx_hash}


@app.post("/admin/institution/status")
def set_institution_status(data: InstitutionStatus):
    tx_hash = send_tx(
        contract.functions.setInstitutionStatus(
            data.institution_id,
            data.authorized
        ),
        SUPER_ADMIN
    )
    return {"status": "ok", "txHash": tx_hash}

# =====================================================
# INSTITUTION ADMIN APIs
# =====================================================

@app.post("/institution/department")
def add_department(data: DepartmentCreate):
    tx_hash = send_tx(
        contract.functions.addDepartment(data.name),
        INSTITUTION_ADMIN
    )
    return {"status": "ok", "txHash": tx_hash}


@app.post("/institution/batch")
def add_batch(data: BatchCreate):
    tx_hash = send_tx(
        contract.functions.addBatchByYear(
            data.department_id,
            data.year
        ),
        INSTITUTION_ADMIN
    )
    return {"status": "ok", "txHash": tx_hash}


@app.post("/institution/student")
def add_student(data: StudentCreate):
    photo_hash = sha256(data.photo_base64.encode()).digest()

    tx_hash = send_tx(
        contract.functions.addStudent(
            w3.to_checksum_address(data.wallet),
            data.department_id,
            data.year,
            data.name,
            data.student_id,
            photo_hash
        ),
        INSTITUTION_ADMIN
    )

    return {"status": "ok", "txHash": tx_hash}

# =====================================================
# READ API (PUBLIC)
# =====================================================

@app.get("/student/{wallet}")
def student_exists(wallet: str):
    exists = contract.functions.studentExists(
        w3.to_checksum_address(wallet)
    ).call()
    return {"exists": exists}
