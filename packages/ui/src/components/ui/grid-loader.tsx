import * as React from 'react';
import { cn } from '@/lib/utils';

interface GridLoaderProps {
  className?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg';
}

const sizeConfig = {
  xs: { container: 'gap-[1px]', dot: 'h-[3px] w-[3px]' },
  sm: { container: 'gap-0.5', dot: 'h-1 w-1' },
  md: { container: 'gap-1', dot: 'h-1.5 w-1.5' },
  lg: { container: 'gap-1.5', dot: 'h-2 w-2' },
};

const GridLoader: React.FC<GridLoaderProps> = ({ className, size = 'md' }) => {
  const config = sizeConfig[size];

  return (
    <div
      className={cn('grid grid-cols-3', config.container, className)}
      aria-label="Loading"
    >
      {Array.from({ length: 9 }, (_, i) => (
        <div
          key={i}
          className={cn('rounded-full bg-current animate-grid-pulse', config.dot)}
          style={{ animationDelay: `${((i % 3) + Math.floor(i / 3)) * 150}ms` }}
        />
      ))}
    </div>
  );
};

export { GridLoader };
