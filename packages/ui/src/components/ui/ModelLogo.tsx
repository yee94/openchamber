import React from 'react';
import { useModelLogo } from '@/hooks/useModelLogo';
import { cn } from '@/lib/utils';

interface ModelLogoProps {
  modelId: string | null | undefined;
  providerId?: string | null;
  alt?: string;
  className?: string;
  onError?: () => void;
}

/**
 * 按模型品牌显示 logo（聚合渠道下优先模型名匹配，Provider 仅作兜底）
 */
export const ModelLogo: React.FC<ModelLogoProps> = ({
  modelId,
  providerId,
  alt,
  className,
  onError: externalOnError,
}) => {
  const { src, onError: handleInternalError, hasLogo, brand } = useModelLogo(modelId, providerId);

  const handleError = React.useCallback(() => {
    handleInternalError();
    externalOnError?.();
  }, [handleInternalError, externalOnError]);

  if (!hasLogo || !src) {
    return null;
  }

  return (
    <img
      src={src}
      alt={alt || `${brand || modelId || providerId || 'model'} logo`}
      // brightness-0 压成纯黑，dark:invert 再翻成纯白，避免品牌原色（Claude 橙 / DeepSeek 蓝）残留
      className={cn('brightness-0 dark:invert object-contain', className)}
      loading="eager"
      decoding="async"
      fetchPriority="high"
      draggable={false}
      onError={handleError}
    />
  );
};
