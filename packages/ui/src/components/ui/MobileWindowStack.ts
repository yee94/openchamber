export type MobileWindowStackEntry = {
  id: string;
  onClose: () => void;
};

type BodyLike = { style: { overflow: string } };

export class MobileWindowStack {
  private entries: MobileWindowStackEntry[] = [];
  private listeners = new Set<() => void>();
  private previousOverflow: string | null = null;

  getSnapshot = (): string | null => this.entries.at(-1)?.id ?? null;

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  add(entry: MobileWindowStackEntry, body?: BodyLike): () => void {
    this.entries = [...this.entries.filter((item) => item.id !== entry.id), entry];
    if (this.entries.length === 1 && body) {
      this.previousOverflow = body.style.overflow;
      body.style.overflow = 'hidden';
    }
    this.emit();
    return () => this.remove(entry.id, body);
  }

  remove(id: string, body?: BodyLike): void {
    const previousLength = this.entries.length;
    this.entries = this.entries.filter((entry) => entry.id !== id);
    if (previousLength > 0 && this.entries.length === 0 && body && this.previousOverflow !== null) {
      body.style.overflow = this.previousOverflow;
      this.previousOverflow = null;
    }
    this.emit();
  }

  closeTop(): void {
    this.entries.at(-1)?.onClose();
  }

  private emit(): void {
    for (const listener of this.listeners) listener();
  }
}

export const mobileWindowStack = new MobileWindowStack();
