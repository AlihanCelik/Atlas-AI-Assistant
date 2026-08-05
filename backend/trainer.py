"""
Atlas - CPU Fine-Tuning
LoRA/QLoRA ile CPU'da model ince ayarı.

Kullanım:
    python trainer.py --data training_data.json --model llama3.2:3b --epochs 3
"""

import argparse
import json
import os
import torch
from datasets import Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling,
)
from peft import LoraConfig, get_peft_model, TaskType


def load_training_data(data_path: str) -> Dataset:
    """
    JSON formatındaki eğitim verisini yükler.
    Format:
    [
        {"instruction": "...", "response": "..."},
        ...
    ]
    """
    with open(data_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Prompt formatına çevir
    formatted = []
    for item in data:
        text = (
            f"<|system|>Sen Atlas'sın, Alihan'ın kişisel asistanısın.</s>\n"
            f"<|user|>{item['instruction']}</s>\n"
            f"<|assistant|>{item['response']}</s>"
        )
        formatted.append({"text": text})

    return Dataset.from_list(formatted)


def train(
    base_model: str,
    data_path: str,
    output_dir: str = "./atlas_finetuned",
    epochs: int = 3,
    batch_size: int = 1,
    max_length: int = 512,
    learning_rate: float = 2e-4,
):
    print(f"[Trainer] Model yükleniyor: {base_model}")
    print(f"[Trainer] Cihaz: CPU (bu zaman alabilir!)")

    tokenizer = AutoTokenizer.from_pretrained(base_model)
    tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        base_model,
        torch_dtype=torch.float32,  # CPU için float32
        low_cpu_mem_usage=True,
    )

    # LoRA konfigürasyonu — CPU'da hafif tutar
    lora_config = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=8,               # rank — düşük = hızlı
        lora_alpha=16,
        target_modules=["q_proj", "v_proj"],
        lora_dropout=0.1,
        bias="none",
    )

    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    # Veri yükle ve tokenize et
    print(f"[Trainer] Veri yükleniyor: {data_path}")
    dataset = load_training_data(data_path)

    def tokenize(examples):
        return tokenizer(
            examples["text"],
            truncation=True,
            max_length=max_length,
            padding="max_length",
        )

    tokenized_dataset = dataset.map(tokenize, batched=True, remove_columns=["text"])

    # Eğitim parametreleri
    training_args = TrainingArguments(
        output_dir=output_dir,
        num_train_epochs=epochs,
        per_device_train_batch_size=batch_size,
        gradient_accumulation_steps=4,
        learning_rate=learning_rate,
        fp16=False,         # CPU'da fp16 yok
        bf16=False,
        logging_steps=10,
        save_steps=100,
        save_total_limit=2,
        no_cuda=True,       # CPU zorla
        report_to="none",
        dataloader_num_workers=0,
    )

    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_dataset,
        data_collator=data_collator,
    )

    print("[Trainer] Eğitim başlıyor...")
    trainer.train()

    print(f"[Trainer] Model kaydediliyor: {output_dir}")
    model.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)
    print("[Trainer] ✅ Tamamlandı!")


def create_sample_data(output_path: str = "training_data.json"):
    """Örnek eğitim verisi oluşturur."""
    sample_data = [
        {
            "instruction": "Merhaba, nasılsın?",
            "response": "İyiyim, teşekkürler! Sana nasıl yardımcı olabilirim?"
        },
        {
            "instruction": "Bugün hava nasıl?",
            "response": "Hava durumuna bakmam gerekiyor, bir saniye!"
        },
        {
            "instruction": "Bana bir şaka anlat.",
            "response": "Programcı neden güneşe çıkmaz? Çünkü Windows'ta bug var, Linux'ta patch yok!"
        },
        {
            "instruction": "Adın ne?",
            "response": "Benim adım Atlas. Alihan'ın kişisel asistanıyım!"
        },
    ]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(sample_data, f, ensure_ascii=False, indent=2)

    print(f"[Trainer] Örnek veri oluşturuldu: {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Atlas Fine-Tuner")
    parser.add_argument("--data", type=str, default="training_data.json")
    parser.add_argument("--model", type=str, default="TinyLlama/TinyLlama-1.1B-Chat-v1.0")
    parser.add_argument("--output", type=str, default="./atlas_finetuned")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--create-sample", action="store_true")

    args = parser.parse_args()

    if args.create_sample:
        create_sample_data()
    else:
        train(
            base_model=args.model,
            data_path=args.data,
            output_dir=args.output,
            epochs=args.epochs,
        )
