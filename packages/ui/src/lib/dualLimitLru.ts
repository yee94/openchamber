type DualLimitLruOptions = {
    maxEntries: number;
    maxBytes: number;
};

type WeightedValue<Value> = {
    value: Value;
    bytes: number;
};

export class DualLimitLru<Key, Value> {
    readonly #maxEntries: number;
    readonly #maxBytes: number;
    readonly #entries = new Map<Key, WeightedValue<Value>>();
    #byteSize = 0;

    constructor(options: DualLimitLruOptions) {
        this.#maxEntries = Math.max(0, Math.floor(options.maxEntries));
        this.#maxBytes = Math.max(0, Math.floor(options.maxBytes));
    }

    get size(): number {
        return this.#entries.size;
    }

    get byteSize(): number {
        return this.#byteSize;
    }

    get(key: Key): Value | undefined {
        const entry = this.#entries.get(key);
        if (!entry) {
            return undefined;
        }

        this.#entries.delete(key);
        this.#entries.set(key, entry);
        return entry.value;
    }

    set(key: Key, value: Value, byteWeight: number): void {
        const existing = this.#entries.get(key);
        if (existing) {
            this.#byteSize -= existing.bytes;
            this.#entries.delete(key);
        }

        const bytes = Math.max(0, Math.ceil(byteWeight));
        if (this.#maxEntries === 0 || bytes > this.#maxBytes) {
            return;
        }

        this.#entries.set(key, { value, bytes });
        this.#byteSize += bytes;
        this.#evictToLimits();
    }

    clear(): void {
        this.#entries.clear();
        this.#byteSize = 0;
    }

    #evictToLimits(): void {
        while (this.#entries.size > this.#maxEntries || this.#byteSize > this.#maxBytes) {
            const oldestKey = this.#entries.keys().next().value as Key | undefined;
            if (oldestKey === undefined) {
                break;
            }
            const oldest = this.#entries.get(oldestKey);
            this.#entries.delete(oldestKey);
            if (oldest) {
                this.#byteSize -= oldest.bytes;
            }
        }
    }
}
